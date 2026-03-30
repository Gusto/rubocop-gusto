# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks that Sidekiq `perform` methods do not use keyword arguments.
      # Sidekiq serializes job arguments to JSON for storage in Redis. JSON
      # does not distinguish symbol keys from string keys, so when a job is
      # retried the deserialized arguments will have string keys and Ruby
      # will raise `ArgumentError: unknown keyword` when trying to call the
      # method with keyword syntax.
      #
      # @example
      #   # bad
      #   class MyWorker
      #     include Sidekiq::Worker
      #
      #     def perform(user_id:, action:)
      #       User.find(user_id).send(action)
      #     end
      #   end
      #
      #   # good
      #   class MyWorker
      #     include Sidekiq::Worker
      #
      #     def perform(user_id, action)
      #       User.find(user_id).send(action)
      #     end
      #   end
      #
      class SidekiqParams < Base
        MSG = "Sidekiq perform methods cannot take keyword arguments"
        PROHIBITED_ARG_TYPES = Set.new(%i[kwoptarg kwarg]).freeze

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
