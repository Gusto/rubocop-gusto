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
        # The accessor list is `PiiMethods`, set on the `Gusto/Logging` department.
        #
        # @example
        #   # bad
        #   Rails.logger.info("User: #{user.email}")
        #   logger.warn("Failed for #{employee.ssn}")
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
              next unless pii_methods.include?(send_node.method_name)
              next if passed_to_predicate?(send_node)

              add_offense(send_node, message: format(MSG, method: send_node.method_name))
            end
          end

          alias_method :on_csend, :on_send

          private

          # A predicate logs its boolean result, not the PII value it was given.
          def passed_to_predicate?(node)
            parent = node.parent
            parent.call_type? && parent.predicate_method?
          end
        end
      end
    end
  end
end
