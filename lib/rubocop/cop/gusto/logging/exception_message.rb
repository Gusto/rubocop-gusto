# frozen_string_literal: true

require_relative "log_call_concerns"

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Flags logging the rescued exception's message (`e.message`, `e.to_s`, or `e.inspect`)
        # inside a rescue block. Messages can carry PII from the failing input.
        #
        # Disabled by default because it's high-volume and most messages are benign.
        #
        # @example
        #   # bad
        #   rescue => e
        #     Rails.logger.error("Failed: #{e.message}")
        #     Rails.logger.error("Failed: #{e.inspect}")
        #
        #   # good
        #   rescue => e
        #     Rails.logger.error("Failed: #{e.class.name}")
        #
        class ExceptionMessage < Base
          include LogCallConcerns

          MSG = "Avoid logging exception messages in rescue blocks — they may contain PII. " \
                "Log `e.class.name` or a static description instead."
          RESTRICT_ON_SEND = LOG_METHODS

          MESSAGE_METHODS = %i(message to_s inspect).freeze

          def on_send(node)
            return unless logger_call?(node)

            each_send_in_log(node) do |send_node|
              next unless MESSAGE_METHODS.include?(send_node.method_name)
              next unless rescued_exception?(send_node.receiver)

              add_offense(send_node)
            end
          end

          alias_method :on_csend, :on_send
        end
      end
    end
  end
end
