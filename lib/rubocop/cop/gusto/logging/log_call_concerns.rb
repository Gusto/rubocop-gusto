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
            supported_logger?(node.receiver)
          end

          def supported_logger?(node)
            return false unless node
            return true if rails_logger?(node) || sidekiq_logger?(node) || bare_logger?(node)

            node.call_type? && node.method?(:tagged) && supported_logger?(node.receiver)
          end

          def pii_methods
            @pii_methods ||= Array(cop_config["PiiMethods"] || DEFAULT_PII_METHODS).map(&:to_sym).to_set
          end

          def each_send_in_log(log_node, &callback)
            log_node.arguments.each do |arg|
              yield_sends_from(arg, &callback)
            end

            # Block-form logging carries the message in the block, not the arguments: `logger.info { "..." }`
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
end
