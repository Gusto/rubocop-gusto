# frozen_string_literal: true

require_relative "log_call_concerns"

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Flags logging HTTP response bodies, which may contain PII.
        #
        # The receiver is matched by name: `response`, `resp`, `res`, `http_response`,
        # `api_response`, or anything ending in `_response`, including instance variables.
        #
        # @example
        #   # bad
        #   Rails.logger.info("Response: #{response.body}")
        #
        #   # good
        #   Rails.logger.info("Response status: #{response.status}")
        #
        class ResponseBody < Base
          include LogCallConcerns

          MSG = "Avoid logging HTTP response bodies which may contain PII. " \
                "Log `response.status` and a request identifier instead."
          RESTRICT_ON_SEND = LOG_METHODS

          RESPONSE_NAMES = %w(response resp res http_response api_response).to_set.freeze

          def on_send(node)
            return unless logger_call?(node)

            each_send_in_log(node) do |send_node|
              add_offense(send_node) if response_body_call?(send_node)
            end
          end

          alias_method :on_csend, :on_send

          private

          def response_body_call?(send_node)
            return false unless send_node.method?(:body)

            receiver = send_node.receiver
            return false unless receiver

            name = receiver_name(receiver)
            return false unless name

            response_like_name?(name)
          end

          def receiver_name(receiver)
            if receiver.type?(:lvar, :ivar)
              receiver.children.first.to_s.delete_prefix("@")
            elsif receiver.send_type? && receiver.receiver.nil?
              receiver.method_name
            end
          end

          def response_like_name?(name)
            name_str = name.to_s
            RESPONSE_NAMES.include?(name_str) || name_str.end_with?("_response")
          end
        end
      end
    end
  end
end
