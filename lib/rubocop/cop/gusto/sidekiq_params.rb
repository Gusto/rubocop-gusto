# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags keyword arguments in Sidekiq +perform+ instance methods.
      #
      # Sidekiq serializes job arguments to JSON when enqueuing and deserializes them when
      # performing. JSON has no concept of keyword arguments, so Ruby keyword args are
      # silently converted to string-keyed hashes and fail to match the method signature
      # at runtime. All +perform+ parameters must be positional so they round-trip correctly
      # through JSON serialization.
      #
      # @example bad
      #   def perform(user_id:, company_id:)
      #
      # @example good
      #   def perform(user_id, company_id)
      class SidekiqParams < Base
        MSG = "Sidekiq perform methods cannot take keyword arguments"
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
