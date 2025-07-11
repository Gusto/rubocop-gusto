# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Detects constants in a rake file because they are defined at the top level.
      # It is confusing because the scope looks like it would be in the task or namespace,
      # but actually it is defined at the top level.
      #
      # @example
      #   # bad
      #   task :foo do
      #     class C
      #     end
      #   end
      #
      #   # bad
      #   namespace :foo do
      #     module M
      #     end
      #   end
      #
      #   # good - It is also defined at the top level,
      #   #        but it looks like intended behavior.
      #   class C
      #   end
      #   task :foo do
      #   end
      #
      class RakeConstants < Base
        MSG = 'Do not define a constant in rake file, because they are sometimes `load`ed, instead of `require`d which can lead to warnings about redefining constants'

        # @!method task_or_namespace?(node)
        def_node_matcher :task_or_namespace?, <<-PATTERN
            (block
              (send _ {:task :namespace} ...)
              args
              _
            )
        PATTERN

        def on_casgn(node)
          return unless in_task_or_namespace?(node)

          add_offense(node)
        end

        def on_class(node)
          return unless in_task_or_namespace?(node)

          add_offense(node)
        end

        def on_module(node)
          return unless in_task_or_namespace?(node)

          add_offense(node)
        end

        private

        def in_task_or_namespace?(node)
          node.each_ancestor(:block).any? { |ancestor| task_or_namespace?(ancestor) }
        end
      end
    end
  end
end
