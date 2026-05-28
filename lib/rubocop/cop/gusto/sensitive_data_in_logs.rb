# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Detects potential PII leaks in log statements.
      #
      # Checks for high-confidence patterns where sensitive data is passed to
      # logger methods: PII accessor methods in interpolation, raw params,
      # exception messages in rescue blocks, HTTP response bodies, and object
      # serialization methods like `.inspect` or `.to_json`.
      #
      # @example CheckPiiAccessors (default: true)
      #
      #   # bad
      #   Rails.logger.info("User: #{user.email}")
      #   logger.warn("Failed for #{employee.ssn}")
      #
      #   # good
      #   Rails.logger.info("User: #{user.id}")
      #   logger.info("Status: #{record.uuid}")
      #
      # @example CheckRawParams (default: true)
      #
      #   # bad
      #   Rails.logger.info(params)
      #   logger.info(params.inspect)
      #
      #   # good
      #   Rails.logger.info(params.slice(:id, :status))
      #
      # @example CheckErrorMessage (default: true)
      #
      #   # bad
      #   rescue => e
      #     Rails.logger.error("Failed: #{e.message}")
      #
      #   # good
      #   rescue => e
      #     Rails.logger.error("Failed: #{e.class.name}")
      #
      # @example CheckResponseBody (default: true)
      #
      #   # bad
      #   Rails.logger.info("Response: #{response.body}")
      #
      #   # good
      #   Rails.logger.info("Response status: #{response.status}")
      #
      # @example CheckObjectSerialization (default: true)
      #
      #   # bad
      #   Rails.logger.info(user.inspect)
      #   logger.info(employee.to_json)
      #
      #   # good
      #   Rails.logger.info("#{user.class.name}##{user.id}")
      #
      class SensitiveDataInLogs < Base
        MSG_PII_ACCESSOR = "Avoid logging PII accessor `.%{method}`. " \
                           "Log an identifier instead, or use `Sensitivity::Loggable#serialize_for_logging`."
        MSG_RAW_PARAMS = "Avoid logging raw `params` which may contain PII. " \
                         "Use `params.slice(...)` or `params.permit(...)` to select safe fields."
        MSG_ERROR_MESSAGE = "Avoid logging exception messages in rescue blocks — they may contain PII. " \
                            "Log `e.class.name` or a static description instead."
        MSG_RESPONSE_BODY = "Avoid logging HTTP response bodies which may contain PII. " \
                            "Log `response.status` and a request identifier instead."
        MSG_OBJECT_SERIALIZATION = "Avoid logging `.%{method}` on objects — it may serialize PII fields. " \
                                   "Log specific safe attributes instead."

        LOG_METHODS = %i(debug info warn error fatal log).freeze
        RESTRICT_ON_SEND = LOG_METHODS

        DEFAULT_PII_METHODS = %w(
          email ssn social_security_number first_name last_name full_name
          phone phone_number ein tin account_number routing_number
          date_of_birth address bank_account_number
        ).freeze

        RESPONSE_NAMES = %w(response resp res http_response api_response).to_set.freeze

        # @!method rails_logger?(node)
        def_node_matcher :rails_logger?, <<~PATTERN
          (send (const {nil? cbase} :Rails) :logger)
        PATTERN

        # @!method sidekiq_logger?(node)
        def_node_matcher :sidekiq_logger?, <<~PATTERN
          (send (const {nil? cbase} :Sidekiq) :logger)
        PATTERN

        # @!method bare_logger?(node)
        def_node_matcher :bare_logger?, <<~PATTERN
          (send nil? :logger)
        PATTERN

        # @!method raw_params?(node)
        def_node_matcher :raw_params?, <<~PATTERN
          (send nil? :params)
        PATTERN

        # @!method params_serialization?(node)
        def_node_matcher :params_serialization?, <<~PATTERN
          (send (send nil? :params) {:to_s :inspect :to_json :to_yaml} ...)
        PATTERN

        # @!method safe_params?(node)
        def_node_matcher :safe_params?, <<~PATTERN
          (send (send nil? :params) {:slice :permit :except :fetch :dig :[] :require} ...)
        PATTERN

        def on_send(node)
          return unless logger_call?(node)

          check_pii_accessors(node) if check_enabled?("CheckPiiAccessors")
          check_raw_params(node) if check_enabled?("CheckRawParams")
          check_error_message(node) if check_enabled?("CheckErrorMessage")
          check_response_body(node) if check_enabled?("CheckResponseBody")
          check_object_serialization(node) if check_enabled?("CheckObjectSerialization")
        end

        alias_method :on_csend, :on_send

        private

        def logger_call?(node)
          receiver = node.receiver
          return false unless receiver

          rails_logger?(receiver) || sidekiq_logger?(receiver) || bare_logger?(receiver)
        end

        def pii_methods
          @pii_methods ||= Array(cop_config["PiiMethods"] || DEFAULT_PII_METHODS).map(&:to_sym).to_set
        end

        def check_enabled?(key)
          cop_config.fetch(key, true)
        end

        # Pattern 1: PII accessor methods in log arguments.
        # Only flags `receiver.pii_method`, not bare `pii_method` calls.
        def check_pii_accessors(log_node)
          each_send_in_log(log_node) do |send_node|
            next unless send_node.receiver
            next unless pii_methods.include?(send_node.method_name)

            add_offense(send_node, message: format(MSG_PII_ACCESSOR, method: send_node.method_name))
          end
        end

        # Pattern 2: Logging raw params
        def check_raw_params(log_node)
          each_send_in_log(log_node) do |node|
            if raw_params?(node) && !params_with_method_call?(node)
              add_offense(node, message: MSG_RAW_PARAMS)
            elsif params_serialization?(node)
              add_offense(node, message: MSG_RAW_PARAMS)
            end
          end
        end

        # Pattern 3: e.message in rescue blocks
        def check_error_message(log_node)
          rescue_variable = find_rescue_variable(log_node)
          return unless rescue_variable

          each_send_in_log(log_node) do |send_node|
            next unless send_node.method?(:message) || send_node.method?(:to_s)

            receiver = send_node.receiver
            next unless receiver&.lvar_type?
            next unless receiver.children.first == rescue_variable

            add_offense(send_node, message: MSG_ERROR_MESSAGE)
          end
        end

        # Pattern 4: response.body in log calls
        def check_response_body(log_node)
          each_send_in_log(log_node) do |send_node|
            next unless response_body_call?(send_node)

            add_offense(send_node, message: MSG_RESPONSE_BODY)
          end
        end

        # Pattern 5: .inspect, .to_json, .as_json, .to_yaml, .attributes
        def check_object_serialization(log_node)
          each_send_in_log(log_node) do |node|
            next unless object_serialization?(node)

            add_offense(node, message: format(MSG_OBJECT_SERIALIZATION, method: node.method_name))
          end
        end

        def object_serialization?(node)
          return false unless %i(inspect to_json as_json to_yaml attributes).include?(node.method_name)

          receiver = node.receiver
          return false unless receiver
          return false if receiver.literal? || receiver.hash_type? || receiver.array_type?

          true
        end

        def response_body_call?(send_node)
          return false unless send_node.method?(:body)

          receiver = send_node.receiver
          return false unless receiver

          name = receiver_name(receiver)
          return false unless name

          response_like_name?(name)
        end

        def receiver_name(receiver)
          if receiver.lvar_type?
            receiver.children.first
          elsif receiver.send_type? && receiver.receiver.nil?
            receiver.method_name
          end
        end

        def response_like_name?(name)
          name_str = name.to_s
          RESPONSE_NAMES.include?(name_str) || name_str.end_with?("_response")
        end

        def params_with_method_call?(params_node)
          parent = params_node.parent
          return false unless parent.send_type?

          safe_params?(parent) || params_serialization?(parent)
        end

        def find_rescue_variable(node)
          node.each_ancestor(:resbody) do |resbody|
            exception_var = resbody.exception_variable
            return exception_var.children.first if exception_var&.lvasgn_type?
          end
          nil
        end

        # Yields every send/csend node in the log call's arguments and block body.
        def each_send_in_log(log_node, &callback)
          log_node.arguments.each do |arg|
            yield_sends_from(arg, &callback)
          end

          # Handle block-form logging: Rails.logger.info { "..." }
          parent_node = log_node.parent
          if parent_node&.block_type? && parent_node.send_node == log_node
            yield_sends_from(parent_node.body, &callback)
          end
        end

        def yield_sends_from(node, &callback)
          return unless node

          yield node if node.call_type?
          node.each_descendant(:call, &callback)
        end
      end
    end
  end
end
