# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Log-call detection and argument traversal shared by the `Gusto/Logging` cops.
        module LogCallConcerns
          extend NodePattern::Macros

          LOG_METHODS = %i(debug info warn error fatal log).freeze

          DEFAULT_PII_METHODS = %w(
            email ssn social_security_number first_name last_name full_name
            phone phone_number ein tin tax_id account_number routing_number
            date_of_birth address bank_account_number
          ).freeze

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

          private

          def logger_call?(node)
            receiver = node.receiver
            return false unless receiver

            rails_logger?(receiver) || sidekiq_logger?(receiver) || bare_logger?(receiver)
          end

          def pii_methods
            @pii_methods ||= Array(cop_config["PiiMethods"] || DEFAULT_PII_METHODS).map(&:to_sym).to_set
          end

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

          def find_rescue_variable(node)
            node.each_ancestor(:resbody) do |resbody|
              exception_var = resbody.exception_variable
              return exception_var.children.first if exception_var&.lvasgn_type?
            end
            nil
          end

          def rescue_variable?(node, rescue_variable)
            node&.lvar_type? && node.children.first == rescue_variable
          end
        end
      end
    end
  end
end
