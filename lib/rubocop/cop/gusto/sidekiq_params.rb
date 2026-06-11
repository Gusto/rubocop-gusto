# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Disallow keyword arguments on Sidekiq `perform` methods. Sidekiq
      # serializes job arguments as JSON and replays them positionally, so
      # keyword arguments are not preserved.
      #
      # @example
      #   # bad
      #   def perform(user_id:, force: false)
      #   end
      #
      #   # good
      #   def perform(user_id, force = false)
      #   end
      class SidekiqParams < Base
        MSG = "Sidekiq perform methods cannot take keyword arguments"

        # @!method perform_with_kwargs?(node)
        def_node_matcher :perform_with_kwargs?, <<~PATTERN
          (def :perform (args <{kwarg kwoptarg} ...>) ...)
        PATTERN

        def on_def(node)
          add_offense(node) if perform_with_kwargs?(node)
        end
      end
    end
  end
end
