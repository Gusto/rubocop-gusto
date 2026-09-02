# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Flags a runtime-crash nullability mismatch between a GraphQL field declaration
        # and its Sorbet resolver signature: a `null: false` field with a resolver that
        # returns `T.nilable`. GraphQL raises a null violation for any input path that
        # returns nil.
        #
        # @example Bad - crashes at runtime
        #   field :cutoff_time, GraphQL::Types::ISO8601DateTime, null: false
        #   sig { override.returns(T.nilable(Time)) }
        #   def cutoff_time = object.cutoff_time
        #
        # @example Good - field and sig agree
        #   field :cutoff_time, GraphQL::Types::ISO8601DateTime, null: true
        #   sig { override.returns(T.nilable(Time)) }
        #   def cutoff_time = object.cutoff_time
        class NullabilityMismatch < Base
          MSG_NON_NULL_NILABLE =
            "Field `:%{name}` is declared `null: false` but resolver sig returns `T.nilable`. " \
            "Either mark the field `null: true` or change the sig."

          FIELD_NULL_VALUE = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :field (sym $_) _ ... (hash <(pair (sym :null) $boolean) ...>))
          PATTERN

          NILABLE_CALL = RuboCop::AST::NodePattern.new("(send (const {nil? cbase} :T) :nilable ...)")

          # Node types that open a new lexical scope. Field declarations and resolver defs are
          # correlated within a single class body, so the walk must not cross these boundaries:
          # a nested class gets its own `on_class` invocation.
          SCOPE_BOUNDARY = %i(class module sclass).freeze

          def on_class(node)
            return unless node.body

            fields = collect_fields(node.body)
            return if fields.empty?

            each_in_scope(node.body, :def) do |def_node|
              check_resolver(def_node, fields)
            end
          end

          private

          def collect_fields(body)
            fields = {}
            each_in_scope(body, :send) do |send_node|
              FIELD_NULL_VALUE.match(send_node) do |name, null_value|
                fields[name] = { node: send_node, nullable: null_value.true_type? }
              end
            end
            fields
          end

          def check_resolver(def_node, fields)
            field_info = fields[def_node.method_name]
            return unless field_info

            sig = def_node.left_sibling
            return unless sig_block?(sig)

            returns = sig.each_descendant(:send).select { |send_node| send_node.method?(:returns) }
            return if returns.none?

            nilable = returns.any? { |ret| returns_contains?(ret, NILABLE_CALL) }

            if nilable && !field_info[:nullable]
              add_offense(field_info[:node], message: format(MSG_NON_NULL_NILABLE, name: def_node.method_name))
            end
          end

          # Walks `node` and its descendants for nodes of `type`, without descending into nested
          # class/module bodies (see SCOPE_BOUNDARY).
          def each_in_scope(node, type, &block)
            yield node if node.type == type
            return if SCOPE_BOUNDARY.include?(node.type)

            node.each_child_node { |child| each_in_scope(child, type, &block) }
          end

          def sig_block?(node)
            node&.block_type? && node.method?(:sig)
          end

          # True when any argument of the `returns(...)` call, at any depth (e.g. inside
          # `T::Promise[...]`), matches the given `T.<method>` pattern.
          def returns_contains?(returns_node, pattern)
            returns_node.arguments.any? do |arg|
              pattern.match(arg) || arg.each_descendant(:send).any? { |send_node| pattern.match(send_node) }
            end
          end
        end
      end
    end
  end
end
