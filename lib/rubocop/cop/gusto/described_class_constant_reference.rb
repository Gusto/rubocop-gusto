# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags constants that are scoped through `described_class`, e.g.
      # `described_class::Worker`.
      #
      # `described_class` is an RSpec helper method resolved at runtime, so
      # Sorbet's static analysis treats `described_class::Worker` as a dynamic
      # constant reference and cannot resolve it (`Dynamic constant references
      # are unsupported`, https://srb.help/5001). Reference the constant by its
      # fully-qualified name instead. A bare `described_class` (with no `::`
      # constant lookup) is an ordinary method call and is left alone.
      #
      # Autocorrection replaces `described_class` with the constant that the
      # enclosing example group describes. It is marked unsafe
      # (`SafeAutoCorrect: false`) because the rewrite relies on the described
      # constant being a statically-written name; review the result before
      # committing. In particular, a constant defined on an *ancestor* of the
      # described class is qualified against the described class itself, which
      # is correct at runtime but which Sorbet cannot resolve through the
      # inheritance chain -- re-point those to the defining ancestor by hand.
      #
      # @example
      #   # bad
      #   RSpec.describe Payments::Processor do
      #     describe described_class::Worker do
      #     end
      #   end
      #
      #   # good
      #   RSpec.describe Payments::Processor do
      #     describe Payments::Processor::Worker do
      #     end
      #   end
      #
      #   # good - `RSpec.describe self` resolves to the enclosing namespace
      #   module Payments
      #     RSpec.describe self do
      #       it { expect(Payments::TIMEOUT).to eq(5) }
      #     end
      #   end
      #
      #   # good - a bare `described_class` is not a constant reference
      #   RSpec.describe Payments::Processor do
      #     subject { described_class.new }
      #   end
      class DescribedClassConstantReference < Base
        extend AutoCorrector

        MSG = "Use the fully-qualified constant name instead of scoping it through " \
              "`described_class`, which Sorbet cannot resolve statically."

        # A constant whose scope is a no-receiver `described_class`, e.g.
        # `described_class::Worker`.
        # @!method const_scoped_on_described_class?(node)
        def_node_matcher :const_scoped_on_described_class?, <<~PATTERN
          (const (send nil? :described_class) _)
        PATTERN

        # An example group, capturing its first argument: a constant
        # (`RSpec.describe Foo do`, `context Foo do`), `self`
        # (`RSpec.describe self do`), and so on.
        # @!method example_group_described_argument(node)
        def_node_matcher :example_group_described_argument, <<~PATTERN
          (block
            (send {(const nil? :RSpec) nil?}
              {:describe :xdescribe :fdescribe :context :xcontext :fcontext :feature :example_group}
              $_ ...)
            ...)
        PATTERN

        # Whether a node routes through a no-receiver `described_class`.
        # @!method scoped_through_described_class?(node)
        def_node_search :scoped_through_described_class?, <<~PATTERN
          (send nil? :described_class)
        PATTERN

        def on_const(node)
          return unless const_scoped_on_described_class?(node)

          scope = node.children[0]
          add_offense(scope) do |corrector|
            replacement = described_class_replacement(node)
            corrector.replace(scope, replacement) if replacement
          end
        end

        private

        # The fully-qualified name (as a String) that `described_class` resolves
        # to lexically, from the nearest enclosing example group, or nil if it
        # cannot be determined statically.
        #
        # - `describe SomeClass` resolves to that constant's written name.
        # - `describe self` resolves to the enclosing module/class namespace.
        # - `describe described_class::X` qualifies the describe argument itself
        #   against the outer group; a reference in such a group's *body* resolves
        #   at runtime to the scoped (statically unknown) class, so we decline to
        #   autocorrect it. Once the enclosing `described_class::X` is rewritten,
        #   a later pass resolves the body reference correctly.
        # - Any other describe argument (e.g. a string) is skipped, and the
        #   search continues at the next enclosing example group.
        def described_class_replacement(node)
          node.each_ancestor(:block) do |block_node|
            described_argument = example_group_described_argument(block_node)
            next if described_argument.nil?

            if described_argument.self_type?
              namespace = enclosing_namespace(block_node)
              return namespace if namespace
            elsif described_argument.const_type?
              return described_argument.source unless scoped_through_described_class?(described_argument)
              return nil unless reference_within_described_constant?(described_argument, node)
            end
          end
          nil
        end

        # The fully-qualified name of the module/class lexically enclosing the
        # example group, which is what `self` refers to in `RSpec.describe self`.
        def enclosing_namespace(block_node)
          names = block_node.each_ancestor(:class, :module).map { |mod| mod.children.first.source }
          return if names.empty?

          names.reverse.join("::")
        end

        # Whether the offending constant is the described constant itself (the
        # describe argument) rather than a reference inside the group's body.
        def reference_within_described_constant?(described_constant, node)
          node.equal?(described_constant) ||
            described_constant.each_descendant(:const).any? { |const_node| const_node.equal?(node) }
        end
      end
    end
  end
end
