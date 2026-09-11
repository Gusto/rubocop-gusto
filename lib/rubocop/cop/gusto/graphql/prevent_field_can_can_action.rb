# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        class PreventFieldCanCanAction < Base
          MSG =
            "Field can_can_actions will soon be deprecated. Please list out the individual fields "\
            "in the appropriate ability files."
          RESTRICT_ON_SEND = %i(field).freeze

          FIELD_WITH_CAN_CAN_ACTION = RuboCop::AST::NodePattern.new(<<-PATTERN)
            (send nil? :field (sym ...) ... (hash <(pair (sym :can_can_action) { (nil) (sym ...)}) ...>))
          PATTERN

          def on_send(node)
            return unless FIELD_WITH_CAN_CAN_ACTION.match(node)

            add_offense(node)
          end
        end
      end
    end
  end
end
