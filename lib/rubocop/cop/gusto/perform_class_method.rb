# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for a defined `.perform` class method in Sidekiq workers. These
      # are most likely intended to have been instance methods.
      #
      # @example
      #   # bad
      #   class MyWorker
      #     include Sidekiq::Worker
      #
      #     def self.perform
      #       # ...
      #     end
      #   end
      #
      #   # good
      #   class MyWorker
      #     include Sidekiq::Worker
      #
      #     def perform
      #       # ...
      #     end
      #   end
      #
      class PerformClassMethod < Base
        MSG = "Class-level `perform` method is being defined. Did you mean to use an instance method?"
        WORKER_FALLBACK = %w(Sidekiq::Worker).freeze
        WORKER_MODULES = "WorkerModules"

        # @!method worker_module_include?(node)
        def_node_matcher :worker_module_include?, <<~PATTERN
          (send nil? :include (const _ _))
        PATTERN

        def on_def(node)
          return unless node.method?(:perform)
          return unless (method_type = perform_class_method_type(node))
          return unless is_sidekiq_worker?(node, method_type)

          add_offense(node)
        end
        alias_method :on_defs, :on_def

        private

        def perform_class_method_type(node)
          if node.receiver&.self_type?
            :self
          elsif node.parent.sclass_type?
            :sclass
          end
        end

        def is_sidekiq_worker?(search_node, method_type)
          search_node = search_node.parent if method_type == :sclass
          search_node.parent.each_child_node.any? do |sibling|
            worker_module_include?(sibling) &&
              worker_modules.include?(sibling.first_argument.const_name)
          end
        end

        def worker_modules
          @worker_modules ||= cop_config.fetch(WORKER_MODULES, WORKER_FALLBACK)
        end
      end
    end
  end
end
