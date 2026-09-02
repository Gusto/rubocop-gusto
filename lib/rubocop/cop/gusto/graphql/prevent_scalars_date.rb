# frozen_string_literal: true

# Behaves similar to graphql_float linter but for ensuring the proper Date type
module RuboCop
  module Cop
    module Gusto
      module Graphql
        class PreventScalarsDate < Base
          MSG =
            "Instead of using Graphql::Scalars::Date, use GraphQL::Types::ISO8601Date or GraphQL::Types::ISO8601DateTime. "\
            "Graphql::Scalars::Date is an artifact of when the graphql-ruby library did not provide out of the box support for dates"
          RESTRICT_ON_SEND = %i(field argument).freeze

          SCALAR_DATE_TYPE = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? {:field :argument} (sym ...)
              $(const
                (const
                  {(const nil? :Graphql) (const (cbase) :Graphql)}
                  :Scalars)
                :Date)
              ...)
          PATTERN

          def on_send(node)
            SCALAR_DATE_TYPE.match(node) do |scalar_date_node|
              add_offense(scalar_date_node)
            end
          end
        end
      end
    end
  end
end
