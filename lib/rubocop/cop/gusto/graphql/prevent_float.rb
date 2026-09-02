# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Checks for the use of Float in GraphQL arguments and fields
        # Gusto has a custom scalar for USDollars and Decimal to avoid loss of precision
        # when serializing floating point numbers to strings
        #
        # @examples
        #  # bad
        #  field :amount, Float, null: false
        #  # bad
        #  field :amount, GraphQL::Types::Float, null: false
        #  #bad
        #  argument :amount, Float, required: true do
        #    description 'Amount in dollars to deposit'
        #  end
        # # good
        # field :amount, Gusto::GraphQL::Scalars::Decimal, null: false
        # # good
        # argument :amount, Gusto::GraphQL::Scalars::USDollars, required: true do
        #   description 'Amount in dollars to deposit'
        # end
        class PreventFloat < Base
          MSG =
            "Do not use Float in GraphQL. Use a fixed-precision scalar instead, so money and "\
            "decimal values are not subject to floating point loss of precision."
          RESTRICT_ON_SEND = %i(argument field).freeze

          # The below is what our AST looks like when hitting the method call of `argument` that occurs in GraphQL mutations
          # It would look the same for `field` methods as well that are in object declarations
          #
          #  s(:send, nil, :argument,
          #   s(:sym, :principal),
          #   s(:const, nil, :Float),
          #   s(:hash,
          #     s(:pair,
          #       s(:sym, :required),
          #       s(:true)),
          #     s(:pair,
          #       s(:sym, :sensitive),
          #       s(:false))))
          #
          # We are matching on a case where the second argument is a Float
          # NodePattern.new("(send nil? :argument (sym ...) (const nil? :Float) ...)").match(node) => true where node is the above
          #
          # graphql-ruby treats `GraphQL::Types::Float` as `Float`, so matching only the bare spelling leaves a bypass.
          FLOAT_TYPE = "(const {nil? (const (const {nil? cbase} :GraphQL) :Types)} :Float)"

          ARGUMENT_OR_FIELD_WITH_FLOAT_TYPE = RuboCop::AST::NodePattern.new(<<-PATTERN)
              (send nil? {:argument :field} (sym ...) #{FLOAT_TYPE} ...)
          PATTERN

          def on_send(node)
            return unless ARGUMENT_OR_FIELD_WITH_FLOAT_TYPE.match(node)

            add_offense(node)
          end
        end
      end
    end
  end
end
