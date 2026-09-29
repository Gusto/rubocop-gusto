# frozen_string_literal: true

require_relative "log_call_concerns"

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Flags serializing objects in log calls with `.to_json`, `.as_json`, `.to_yaml`, or
        # `.attributes`, which may dump every field of a record. `.inspect` is checked only when
        # `CheckInspect` is on, since it's usually quoting a scalar.
        #
        # Literals and constants are skipped. So are receivers named like identifiers, per
        # `AllowedReceiverNames` (exact) and `AllowedReceiverSuffixes`, unless the name is in
        # `PiiMethods`. Raw `params` and `e.inspect` are left to `RawParams` and `ExceptionMessage`.
        #
        # @example
        #   # bad
        #   logger.info(employee.to_json)
        #   Rails.logger.info(user.attributes)
        #
        #   # good
        #   Rails.logger.info("#{user.class.name}##{user.id}")
        #   Rails.logger.info(DEFAULT_OPTIONS.to_json)
        #   Rails.logger.info("Companies: #{company_uuids.to_json}")
        #
        # @example CheckInspect: true
        #   # bad
        #   Rails.logger.info(user.inspect)
        #
        #   # good
        #   Rails.logger.info("Status: #{status.inspect}")
        #
        class SerializedObject < Base
          include LogCallConcerns

          MSG = "Avoid logging `.%{method}` on objects — it may serialize PII fields. " \
                "Log specific safe attributes instead."
          RESTRICT_ON_SEND = LOG_METHODS

          SERIALIZATION_METHODS = %i(to_json as_json to_yaml attributes).freeze

          def on_send(node)
            return unless logger_call?(node)

            rescue_variable = find_rescue_variable(node)

            each_send_in_log(node) do |send_node|
              next unless checked_method?(send_node) && object_serialization?(send_node)
              next if send_node.method?(:inspect) && rescue_variable?(send_node.receiver, rescue_variable)

              add_offense(send_node, message: format(MSG, method: send_node.method_name))
            end
          end

          alias_method :on_csend, :on_send

          private

          def checked_method?(node)
            SERIALIZATION_METHODS.include?(node.method_name) || (node.method?(:inspect) && cop_config["CheckInspect"])
          end

          def object_serialization?(node)
            receiver = node.receiver
            return false unless receiver
            return false if receiver.literal? || receiver.hash_type? || receiver.array_type? || receiver.const_type?
            return false if raw_params?(receiver)

            !allowed_receiver?(receiver)
          end

          def allowed_receiver?(receiver)
            name = value_name(receiver)
            return false if name.nil? || pii_methods.include?(name.to_sym)

            allowed_receiver_names.include?(name) || allowed_receiver_suffixes.any? { |suffix| name.end_with?(suffix) }
          end

          def allowed_receiver_names
            @allowed_receiver_names ||= Array(cop_config["AllowedReceiverNames"]).to_set
          end

          def allowed_receiver_suffixes
            @allowed_receiver_suffixes ||= Array(cop_config["AllowedReceiverSuffixes"])
          end

          def value_name(node)
            case node.type
            when :lvar, :ivar then node.children.first.to_s.delete_prefix("@")
            when :send, :csend then literal_key(node) || node.method_name.to_s
            end
          end

          def literal_key(node)
            key = node.first_argument if node.method?(:[])
            key.value.to_s if key&.type?(:sym, :str)
          end
        end
      end
    end
  end
end
