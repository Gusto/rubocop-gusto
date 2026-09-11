# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        class PaginateArrays < Base
          MSG = "Field returns an unbounded array of `%{field_type}`. Paginate it, or declare it " \
            "a deliberately bounded list."
          RESTRICT_ON_SEND = %i(field).freeze

          ARRAY_FIELD = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :field (sym ...) $(array $...) ...)
          PATTERN

          def on_send(node)
            ARRAY_FIELD.match(node) do |unbounded_list, field|
              add_offense(unbounded_list, message: format(MSG, field_type: field.first&.const_name))
            end
          end
        end
      end
    end
  end
end
