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
      # committing.
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

        # `described_class` called with no explicit receiver.
        # @!method described_class_call?(node)
        def_node_matcher :described_class_call?, <<~PATTERN
          (send nil? :described_class)
        PATTERN

        # An example group whose first argument is a constant, capturing that
        # constant: `RSpec.describe Foo do`, `describe Foo do`, `context Foo do`.
        # @!method example_group_described_constant(node)
        def_node_matcher :example_group_described_constant, <<~PATTERN
          (block
            (send {(const nil? :RSpec) nil?}
              {:describe :xdescribe :fdescribe :context :xcontext :fcontext :feature :example_group}
              $const ...)
            ...)
        PATTERN

        # Whether a constant subtree routes through `described_class`.
        # @!method scoped_through_described_class?(node)
        def_node_search :scoped_through_described_class?, <<~PATTERN
          (send nil? :described_class)
        PATTERN

        def on_const(node)
          return unless const_scoped_on_described_class?(node)

          scope = node.children[0]
          add_offense(scope) do |corrector|
            described_constant = lexical_described_constant(node)
            corrector.replace(scope, described_constant.source) if described_constant
          end
        end

        private

        # The constant that `described_class` resolves to lexically: the nearest
        # enclosing example group whose described constant does not itself route
        # through `described_class`.
        #
        # When the nearest enclosing group is described via `described_class::X`,
        # the reference is only resolvable if it *is* that describe argument
        # (e.g. `describe described_class::Worker` qualifies against the outer
        # group). A reference in such a group's *body* resolves at runtime to
        # the scoped (and statically unknown) class, so we decline to autocorrect
        # rather than qualify it against the wrong ancestor. Once the enclosing
        # `described_class::X` is itself rewritten, a later pass resolves the
        # body reference correctly.
        def lexical_described_constant(node)
          node.each_ancestor(:block) do |block_node|
            described_constant = example_group_described_constant(block_node)
            next unless described_constant
            return described_constant unless scoped_through_described_class?(described_constant)
            return nil unless reference_within_described_constant?(described_constant, node)
          end
          nil
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
