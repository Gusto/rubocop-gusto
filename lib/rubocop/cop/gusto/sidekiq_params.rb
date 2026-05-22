# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for keyword arguments in Sidekiq `perform` methods. Sidekiq
      # serializes job arguments to JSON, which does not preserve the
      # positional/keyword distinction — keyword arguments are unsupported and
      # will be silently lost when the job is dequeued.
      #
      # @example
      #   # bad
      #   def perform(user_id:, action:)
      #   end
      #
      #   # good
      #   def perform(user_id, action)
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
