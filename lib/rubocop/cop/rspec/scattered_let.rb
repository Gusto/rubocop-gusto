# frozen_string_literal: true

require "rubocop/cop/rspec/scattered_let"

module RuboCop
  module Cop
    module RSpec
      # Patches the upstream `RSpec/ScatteredLet` cop so that Sorbet `sig`
      # declarations attached to `let`/`let!` blocks (Sorbet's RSpec mode)
      # do not interrupt the consecutive-let chain, and are moved together
      # with their `let` when autocorrecting.
      #
      # Without this patch, the upstream cop both flags valid `sig`+`let`
      # arrangements and autocorrects to a broken state where a `sig` is
      # left behind without its `let`.
      #
      # @example
      #   # good (no longer flagged)
      #   context "..." do
      #     sig { returns(Something) }
      #     let(:thing) { create(:something) }
      #
      #     sig { returns(Other) }
      #     let(:other) { create(:other) }
      #   end
      class ScatteredLet
        LetUnit = Struct.new(:sig, :let, :start_index, :length)
        private_constant :LetUnit

        # @!method sig_block?(node)
        def_node_matcher :sig_block?, <<~PATTERN
          (block (send nil? :sig) _ _)
        PATTERN

        private

        def check_let_declarations(body)
          children = body.each_child_node.to_a
          units = build_let_units(children)
          return if units.empty?

          reference_unit = units.first
          expected_start = reference_unit.start_index

          units.each do |unit|
            if unit.start_index == expected_start
              reference_unit = unit
            else
              add_offense(unit.let) do |corrector|
                move_let_unit_after(unit, reference_unit.let, corrector)
              end
            end
            expected_start += unit.length
          end
        end

        def build_let_units(children)
          children.each_with_index.with_object([]) do |(node, idx), units|
            next unless let?(node)

            prev = idx.positive? ? children[idx - 1] : nil
            if prev && sig_block?(prev)
              units << LetUnit.new(prev, node, prev.sibling_index, 2)
            else
              units << LetUnit.new(nil, node, node.sibling_index, 1)
            end
          end
        end

        def move_let_unit_after(unit, reference_let, corrector)
          if unit.sig
            ::RuboCop::RSpec::Corrector::MoveNode.new(
              unit.sig, corrector, processed_source
            ).move_after(reference_let)
          end
          ::RuboCop::RSpec::Corrector::MoveNode.new(
            unit.let, corrector, processed_source
          ).move_after(reference_let)
        end
      end
    end
  end
end
