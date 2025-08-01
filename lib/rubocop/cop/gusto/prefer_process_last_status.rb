# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Don't use the `$?` or `$CHILD_STATUS` global variables. Instead, use `Process.last_status`
      #
      # @example
      #   # bad
      #   $?.exitstatus
      #   $CHILD_STATUS.success?
      #
      #   # good
      #   Process.last_status.exit_status
      #   Process.last_status.success?
      #
      class PreferProcessLastStatus < Base
        extend AutoCorrector

        MSG = "Prefer using `Process.last_status` instead of the global variables: `$?` and `$CHILD_STATUS`."
        OFFENDERS = Set[:$?, :$CHILD_STATUS].freeze

        def on_gvar(node)
          return unless OFFENDERS.include?(node.node_parts.first)

          add_offense(node) { |corrector| autocorrect(corrector, node) }
        end

        def autocorrect(corrector, node)
          corrector.replace(node, "Process.last_status")
        end
      end
    end
  end
end
