# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Requires VCR to be set to not record in tests.
      #
      # @example
      #   # bad
      #   vcr: {record: :all}
      #
      #   # good
      #   vcr: {record: :none}
      #
      # @see https://github.com/vcr/vcr
      #
      class VcrRecordings < Base
        extend AutoCorrector

        MSG = 'VCR should be set to not record in tests. Please use vcr: {record: :none}.'

        # @!method vcr_recording?(node)
        def_node_matcher :vcr_recording?, <<~PATTERN
          (pair (sym :record) (sym $_))
        PATTERN

        def on_pair(node)
          return unless vcr_setting?(node)
          return unless recording_enabled?(node.key.children.first, node.value.children.first)

          add_offense(node) do |corrector|
            replacement = node.source.sub(/: :\w*/, ': :none')
            corrector.replace(node, replacement)
          end
        end

        private

        def vcr_setting?(node)
          node.parent.parent.source.include?('vcr')
        end

        def recording_enabled?(option, value)
          option == :record && value != :none
        end
      end
    end
  end
end
