# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class ExplicitTimeUnits < Base
        MSG = "Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. " \
          "Use explicit time methods instead (e.g., `.days`, `.hours`)."

        PROTECTED_CLASSES = %w(Date Time DateTime).freeze

        RESTRICT_ON_SEND = %i(+ -).freeze

        def on_send(node)
          return unless date_time_arithmetic?(node)

          add_offense(node)
        end

        private

        def date_time_arithmetic?(node)
          # Check if receiver is a Date/Time/DateTime type
          return false unless date_time_type?(node.receiver)

          node.first_argument.type?(:int, :float) || potentially_numeric?(node.first_argument)
        end

        def date_time_type?(node)
          # Check for send nodes that are class methods
          if node.send_type? && node.receiver
            # Handle DateTime.now, Date.today, etc.
            receiver_name = node.receiver.source

            return true if PROTECTED_CLASSES.include?(receiver_name)
          end

          false
        end

        def potentially_numeric?(node)
          # Only flag if it's NOT using a time unit method
          return false if node.send_type? # && TIME_UNIT_METHODS.include?(node.method_name)

          # Variable or method call that might be numeric (int or float)
          node.type?(:send, :ivar, :const)
        end
      end
    end
  end
end
