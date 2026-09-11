# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Disallows direct hash access on GraphQL context.
        # Use typed context methods instead for better type safety.
        #
        # @example
        #   # bad
        #   context[:user_id] | context["user_id"]
        #   ctx[:user_id] | ctx["user_id"]
        #   @context[:user_id] | @context["user_id"]
        #   @ctx[:user_id] | @ctx["user_id"]
        #   do |ctx| ctx[:user_id] end
        #   def resolve(context) context[:user_id] end
        #
        #   # ok
        #   ctx.user_id | @context.user_id | @ctx.user_id
        #
        #   # preferred
        #   context.user_id
        #
        class PreventContextHashAccess < Base
          MSG = "Use typed context methods instead of hash access. " \
                "Example: `context.user_id` instead of `context[:user_id]`."

          RESTRICT_ON_SEND = %i([]).freeze

          # Keys allowed to use hash access on context.
          #
          # current_arguments:
          #   A runtime metadata key added during field resolution as part of graphql-ruby's API.
          #   It contains all arguments passed to the current field, providing access to args that are otherwise not available to resolvers,
          #   for example pagination args (first, last, after, before) that are not directly accessible to resolver via the resolver signature.
          ALLOWED_KEYS = %i(
            current_arguments
          ).freeze

          CONTEXT_BRACKET_ACCESS = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send {(send nil? {:context :ctx}) (lvar {:context :ctx}) (ivar {:@context :@ctx})} :[] ...)
          PATTERN

          LITERAL_KEY = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send _ :[] {(sym $_) (str $_)})
          PATTERN

          def on_send(node)
            return unless CONTEXT_BRACKET_ACCESS.match(node)

            key = LITERAL_KEY.match(node)&.to_sym
            return if key && ALLOWED_KEYS.include?(key)

            add_offense(node)
          end
        end
      end
    end
  end
end
