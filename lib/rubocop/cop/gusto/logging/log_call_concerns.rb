# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Logging
        # Log-call detection and argument traversal shared by the `Gusto/Logging` cops.
        module LogCallConcerns
          extend NodePattern::Macros

          LOG_METHODS = %i(debug info warn error fatal log).freeze
          SIZE_METHODS = %i(size length bytesize).freeze

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

          def params_expression?(node)
            return false unless node
            return true if raw_params?(node)

            node.call_type? && params_expression?(node.receiver)
          end

          def pii_methods
            @pii_methods ||= Array(config.dig("Gusto/Logging", "PiiMethods")).map(&:to_s).to_set
          end

          def pii_method?(method_name)
            name = method_name.to_s
            pii_methods.include?(name) || pii_methods.any? { |pii| name.end_with?("_#{pii}") }
          end

          # A predicate or size logs a boolean or count, not the value it was given.
          def summarized_by_parent?(node)
            parent = node.parent
            parent.call_type? && (parent.predicate_method? || SIZE_METHODS.include?(parent.method_name))
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

          def rescued_exception?(node)
            return false unless node&.lvar_type?

            name = node.children.first
            child = node
            node.each_ancestor do |ancestor|
              case ancestor.type
              when :def, :defs, :class, :module, :sclass
                return false
              when :block
                if ancestor.send_node != child && ancestor.argument_list.any? { |argument| argument.name == name }
                  return false
                end
              when :resbody
                exception_var = ancestor.exception_variable
                return true if exception_var&.lvasgn_type? && exception_var.children.first == name
              end
              child = ancestor
            end
            false
          end
        end
      end
    end
  end
end
