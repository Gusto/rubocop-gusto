# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Sorbet
        # Checks that predicate methods (methods ending with ?) in Sorbet-typed files
        # return boolean values (T::Boolean or true/false literals).
        #
        # This cop categorizes offenses into:
        # - Methods returning nil
        # - Methods returning other non-boolean values
        #
        # A `sig { void }` predicate is left alone. `void` is an explicit declaration that
        # the return value is not meaningful, which is how validator-style methods that only
        # call `errors.add` are annotated.
        #
        # It also provides an unsafe autocorrect feature to change the signature
        # to `returns(T::Boolean)` and coerce the return value to a boolean.
        #
        # @safety
        #   This cop's autocorrect is unsafe because it changes method signatures
        #   and coerces return values using `!!()`, which may alter the behavior
        #   of the code in subtle ways.
        #
        # @example
        #   # bad (returns nil)
        #   sig { returns(T.nilable(String)) }
        #   def valid?
        #     nil
        #   end
        #
        #   # bad (returns non-boolean)
        #   sig { returns(String) }
        #   def valid?
        #     'yes'
        #   end
        #
        #   # good
        #   sig { returns(T::Boolean) }
        #   def valid?
        #     true
        #   end
        #
        #   # good (also acceptable)
        #   sig { returns(T.any(TrueClass, FalseClass)) }
        #   def valid?
        #     true
        #   end
        #
        #   # good (void declares the return value meaningless)
        #   sig { void }
        #   def valid_state?
        #     errors.add(:state, 'is invalid') unless state_ok?
        #   end
        class PredicateBooleanReturn < Base
          extend AutoCorrector

          MSG_RETURNS_NIL = "Predicate method `%{method}` may return nil instead of boolean."
          MSG_RETURNS_NON_BOOLEAN = "Predicate method `%{method}` returns %{type} instead of boolean."

          TYPED_SIGIL = /\A\s*#\s*typed:\s*(true|strict|strong)\b/
          # Starts with `!` or `!!` but not `!=` / `!==`
          NEGATION_PREFIX = /\A!(!|[^=])/
          # Guards `find_sig_node`'s left-sibling walk against a pathological node list
          MAX_SIBLING_LOOKBACK = 10

          def on_def(node)
            return unless node.predicate_method?
            return unless typed_file?

            check_predicate_method(node)
          end
          alias_method :on_defs, :on_def

          private

          def typed_file?
            processed_source.buffer.source.match?(TYPED_SIGIL)
          end

          def check_predicate_method(node)
            return if method_has_non_private_class_method_wrapper?(node)

            sig_node = find_sig_node(node)
            return unless sig_node

            return_type_node = extract_return_type(sig_node)
            return unless return_type_node
            # `void` explicitly declares the return value meaningless, which is how
            # validator-style methods are annotated. Demanding a boolean would contradict
            # that. A command named like a predicate is Naming/PredicateMethod's concern.
            return if return_type_node.method?(:void)

            is_nil_return = returns_nil?(return_type_node)
            is_non_boolean_return = !returns_boolean?(return_type_node)
            return unless is_nil_return || is_non_boolean_return

            if is_nil_return
              message = format(MSG_RETURNS_NIL, method: node.method_name)
            else
              message = format(MSG_RETURNS_NON_BOOLEAN, method: node.method_name, type: format_type(return_type_node))
            end

            add_offense(node, message:) do |corrector|
              autocorrect(corrector, node, return_type_node)
            end
          end

          def autocorrect(corrector, node, return_type_node)
            corrector.replace(return_type_node, "returns(T::Boolean)")

            method_body = node.body
            coerce_last_expression(corrector, method_body) if method_body
          end

          # An expression that is already negated (`!foo` / `!!foo`) is boolean, so it needs
          # no coercion.
          def coerce_last_expression(corrector, method_body)
            last_expression = last_expression_in_body(method_body)
            return unless last_expression && !already_boolean_coerced?(last_expression) &&
              !last_expression.source.match?(NEGATION_PREFIX)

            corrector.insert_before(last_expression, "!!(")
            corrector.insert_after(last_expression, ")")
          end

          def last_expression_in_body(body_node)
            case body_node.type
            when :begin
              body_node.children.last
            else
              body_node # Single expression body
            end
          end

          def already_boolean_coerced?(node)
            node.send_type? && node.method?(:!) &&
              node.receiver.send_type? && node.receiver.method?(:!)
          end

          # Walks left siblings past `private` modifiers to find the method's `sig` block.
          # A `private_class_method def self.foo?` wrapper shifts the starting point to the
          # wrapping send.
          def find_sig_node(method_node)
            parent = method_node.parent
            if parent&.send_type? && parent.method?(:private_class_method)
              prev_sibling = parent.left_sibling
            else
              prev_sibling = method_node.left_sibling
            end

            iteration_count = 0
            while prev_sibling
              iteration_count += 1
              break if iteration_count > MAX_SIBLING_LOOKBACK
              return prev_sibling if sig_block?(prev_sibling)
              break unless prev_sibling.send_type? && prev_sibling.method?(:private)

              prev_sibling = prev_sibling.left_sibling
            end
            nil
          end

          def sig_block?(node)
            node.block_type? && node.method?(:sig)
          end

          def extract_return_type(sig_node)
            sig_node.each_descendant(:send).find do |send_node|
              send_node.method?(:returns) || send_node.method?(:void)
            end
          end

          # `void` is filtered out before this point, so the node is always `returns(...)`.
          def returns_nil?(return_node)
            arg = return_node.first_argument
            return false unless arg

            nilable_type?(arg)
          end

          def returns_boolean?(return_node)
            return false unless return_node.first_argument

            boolean_type?(return_node.first_argument)
          end

          def nilable_type?(node)
            case node.type
            when :send
              if node.method?(:nilable)
                true
              elsif node.method?(:any)
                node.arguments.any? { |arg_node| nil_type?(arg_node) }
              else
                nil_type?(node)
              end
            else
              nil_type?(node)
            end
          end

          # `T.untyped` can be nil but is reported as non-boolean rather than nilable.
          def nil_type?(node)
            node.const_type? && node.const_name == "NilClass"
          end

          def boolean_type?(node)
            case node.type
            when :const
              %w(Boolean TrueClass FalseClass).include?(extract_const_name(node))
            when :send
              t_boolean_union?(node)
            else
              false
            end
          end

          # `T.any(TrueClass, FalseClass)` is the only `T.` send that is boolean.
          def t_boolean_union?(node)
            return false unless node.receiver&.const_type? && node.receiver.const_name == "T"
            return false unless node.method?(:any)

            args = node.arguments
            args.size == 2 &&
              args.all? { |arg_node| arg_node.const_type? && %w(TrueClass FalseClass).include?(arg_node.const_name) }
          end

          def extract_const_name(node)
            if node.children[0]&.const_type? && node.children[0].const_name == "T" && node.children[1] == :Boolean
              "Boolean"
            else
              node.const_name
            end
          end

          def format_type(return_node)
            return "unknown" unless return_node.first_argument

            format_type_arg(return_node.first_argument)
          end

          def format_send_type(node)
            return node.source unless node.receiver&.const_type? && node.receiver.const_name == "T"

            case node.method_name
            when :nilable
              "T.nilable(#{format_type_arg(node.first_argument)})"
            when :any
              "T.any(#{node.arguments.map { |arg_node| format_type_arg(arg_node) }.join(', ')})"
            else
              "T.#{node.method_name}"
            end
          end

          def format_type_arg(node)
            case node.type
            when :const
              extract_const_name(node)
            when :send
              format_send_type(node)
            else
              node.source # For literals or other node types
            end
          end

          # `private_class_method def self.foo?` still reads as a plain definition; any other
          # wrapping send (e.g. a custom decorator) hides the real return type.
          def method_has_non_private_class_method_wrapper?(method_node)
            parent = method_node.parent
            return false unless parent&.send_type?

            !parent.method?(:private_class_method)
          end
        end
      end
    end
  end
end
