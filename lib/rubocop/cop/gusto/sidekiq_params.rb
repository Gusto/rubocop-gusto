# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
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
