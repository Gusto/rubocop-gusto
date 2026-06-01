# frozen_string_literal: true

require "rubocop/rspec/corrector/move_node"

module RuboCop
  module RSpec
    # Namespace for rubocop-rspec autocorrect helpers patched by this gem.
    module Corrector
      # Patches `MoveNode` to treat Sorbet `sig { ... }` blocks as part of the
      # `let`/`subject`/hook they precede.
      #
      # Sorbet's RSpec mode attaches type signatures to memoized helpers via a
      # `sig` block immediately above the declaration:
      #
      #   sig { returns(Something) }
      #   let(:thing) { create(:something) }
      #
      # Several rubocop-rspec cops use `MoveNode` to relocate `let`/`subject`/
      # hook nodes (`ScatteredLet`, `LeadingSubject`, `LetBeforeExamples`,
      # `HooksBeforeExamples`). Without this patch, the move strands the `sig`
      # at the original location. This patch:
      #
      # 1. Extends the source range of the moved node to include a preceding
      #    `sig` block, so `sig` is carried with the move.
      # 2. In `move_before`, redirects the insertion point above a preceding
      #    `sig` on the destination, so the destination's `sig` pairing stays
      #    intact.
      module SigAwareMoveNode
        extend ::RuboCop::AST::NodePattern::Macros

        # @!method sig_block?(node)
        def_node_matcher :sig_block?, <<~PATTERN
          (block (send nil? :sig ...) _ _)
        PATTERN

        def move_before(other)
          sig = preceding_sig_block(other)
          super(sig || other)
        end

        private def node_range(node)
          sig = preceding_sig_block(node)
          return super unless sig

          ::Parser::Source::Range.new(
            buffer,
            begin_pos_with_comment(sig).begin_pos,
            end_line_position(node).end_pos,
          )
        end

        private def preceding_sig_block(node)
          prev = node.left_sibling
          prev if sig_block?(prev)
        end
      end

      MoveNode.prepend(SigAwareMoveNode)
    end
  end
end
