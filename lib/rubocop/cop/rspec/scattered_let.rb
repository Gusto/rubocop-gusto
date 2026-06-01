# frozen_string_literal: true

require "rubocop/cop/rspec/scattered_let"

module RuboCop
  module Cop
    module RSpec
      # Patches the upstream `RSpec/ScatteredLet` cop so that Sorbet `sig`
      # declarations attached to `let`/`let!` blocks (Sorbet's RSpec mode)
      # do not interrupt the consecutive-let chain.
      #
      # Without this patch the upstream cop flags valid `sig`+`let`
      # arrangements because the intervening `sig` block breaks the
      # consecutive-sibling check. (The sig-aware `MoveNode` patch in
      # `lib/rubocop/gusto/move_node_patch.rb` handles dragging the `sig`
      # along during autocorrect.)
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
        LetUnit = Struct.new(:let, :start_index, :length)
        private_constant :LetUnit

        # @!method sig_block?(node)
        def_node_matcher :sig_block?, <<~PATTERN
          (block (send nil? :sig) _ _)
        PATTERN

        private def check_let_declarations(body)
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
                ::RuboCop::RSpec::Corrector::MoveNode.new(
                  unit.let, corrector, processed_source,
                ).move_after(reference_unit.let)
              end
            end
            expected_start += unit.length
          end
        end

        private def build_let_units(children)
          children.each_with_index.with_object([]) do |(node, idx), units|
            next unless let?(node)

            prev = idx.positive? ? children[idx - 1] : nil
            if prev && sig_block?(prev)
              units << LetUnit.new(node, prev.sibling_index, 2)
            else
              units << LetUnit.new(node, node.sibling_index, 1)
            end
          end
        end
      end
    end
  end
end
