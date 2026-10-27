# frozen_string_literal: true

require_relative "log_call_concerns"

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Flags PII accessor methods, such as `.email` or `.ssn`, in log calls.
        #
        # Only calls with a receiver count (`user.email`, not a bare `email`). A predicate on the
        # accessor (`user.email.present?`) is allowed because it logs a boolean, not the value.
        # `PiiMethods` comes from the `Gusto/Logging` department. Each entry also
        # matches as an underscore suffix, so `tax_id` covers `client_tax_id`.
        #
        # @example
        #   # bad
        #   Rails.logger.info("User: #{user.email}")
        #   logger.warn("Failed for #{employee.ssn}")
        #   Rails.logger.info("Tax ID: #{input.client_tax_id}")
        #
        #   # good
        #   Rails.logger.info("User: #{user.id}")
        #   Rails.logger.info("Has email: #{user.email.present?}")
        #
        class PiiAccessor < Base
          include LogCallConcerns

          MSG = "Avoid logging PII accessor `.%{method}`. Log an identifier instead."
          RESTRICT_ON_SEND = LOG_METHODS

          def on_send(node)
            return unless logger_call?(node)

            each_send_in_log(node) do |send_node|
              next unless send_node.receiver
              next unless pii_method?(send_node.method_name)
              next if predicate_receiver?(send_node)

              add_offense(send_node, message: format(MSG, method: send_node.method_name))
            end
          end

          alias_method :on_csend, :on_send

          private

          def predicate_receiver?(node)
            parent = node.parent
            parent.call_type? && parent.predicate_method?
          end
        end
      end
    end
  end
end
