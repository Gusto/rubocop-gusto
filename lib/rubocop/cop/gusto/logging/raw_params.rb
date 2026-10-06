# frozen_string_literal: true

require_relative "log_call_concerns"

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Flags logging raw `params`, which may contain PII.
        #
        # Narrowing with `slice`, `permit`, `except`, `fetch`, `dig`, or `[]` is allowed.
        # `params.require(:key)` on its own is not, because it returns the whole nested hash.
        #
        # @example
        #   # bad
        #   Rails.logger.info(params)
        #   logger.info(params.inspect)
        #   Rails.logger.info(params.require(:user))
        #
        #   # good
        #   Rails.logger.info(params.slice(:id, :status))
        #   Rails.logger.info(params.require(:user).permit(:id))
        #
        class RawParams < Base
          include LogCallConcerns

          MSG = "Avoid logging raw `params` which may contain PII. " \
                "Use `params.slice(...)` or `params.permit(...)` to select safe fields."
          RESTRICT_ON_SEND = LOG_METHODS

          # @!method params_serialization?(node)
          def_node_matcher :params_serialization?, <<~PATTERN
            (call (send nil? :params) {:to_s :inspect :to_json :to_yaml} ...)
          PATTERN

          # @!method required_params?(node)
          def_node_matcher :required_params?, <<~PATTERN
            (call (send nil? :params) :require ...)
          PATTERN

          # @!method safe_params?(node)
          def_node_matcher :safe_params?, <<~PATTERN
            (call {(send nil? :params) #required_params?} {:slice :permit :except :fetch :dig :[]} ...)
          PATTERN

          def on_send(node)
            return unless logger_call?(node)

            each_send_in_log(node) do |send_node|
              add_offense(send_node) if exposed_params?(send_node)
            end
          end

          alias_method :on_csend, :on_send

          private

          def exposed_params?(node)
            raw_params?(node) ? !params_with_method_call?(node) : params_serialization?(node)
          end

          def params_with_method_call?(params_node)
            parent = params_node.parent
            return false unless parent.call_type?
            # `params.require(:key)` returns the whole nested hash, so it is only safe once narrowed.
            return safe_params?(parent.parent) if required_params?(parent)

            safe_params?(parent) || params_serialization?(parent)
          end
        end
      end
    end
  end
end
