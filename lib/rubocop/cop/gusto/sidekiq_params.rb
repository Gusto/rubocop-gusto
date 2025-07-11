# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class SidekiqParams < Base
        MSG = 'Sidekiq perform methods cannot take keyword arguments'
        PROHIBITED_ARG_TYPES = Set.new(%i(kwoptarg kwarg)).freeze

        def on_def(node)
          return unless node.method?(:perform)
          return if node.arguments.empty?

          node.arguments.each_child_node do |arg|
            add_offense(node) if PROHIBITED_ARG_TYPES.include?(arg.type)
          end
        end
      end
    end
  end
end
