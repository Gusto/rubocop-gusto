# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class ExplicitTimeUnits < Base
        MSG = "Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. " \
          "Use explicit time methods instead (e.g., `.days`, `.hours`)."

        RESTRICT_ON_SEND = %i(+ - << >>).freeze

        # Allowed time unit methods (both singular and plural)
        TIME_UNIT_METHODS = %i(
          second seconds
          minute minutes
          hour hours
          day days
          week weeks
          month months
          year years
          fortnight fortnights
        ).freeze

        def on_send(node)
          return unless date_time_arithmetic?(node)

          add_offense(node)
        end

        alias_method :on_csend, :on_send

        private

        def date_time_arithmetic?(node)
          receiver = node.receiver

          # Check if receiver is a Date/Time/DateTime type
          return false unless date_time_type?(receiver)

          # Check if argument exists and is an integer (literal or variable)
          argument = node.first_argument

          argument.type?(:int, :float) || potentially_numeric?(argument)
        end

        def date_time_type?(node)
          # Check for send nodes that are class methods
          if node.send_type? && node.receiver
            # Handle DateTime.now, Date.today, etc.
            receiver_name = node.receiver.source

            return true if %w(Date Time DateTime).include?(receiver_name)
          end

          false
        end

        def potentially_numeric?(node)
          # Only flag if it's NOT using a time unit method
          return false if node.send_type? && TIME_UNIT_METHODS.include?(node.method_name)

          # Variable or method call that might be numeric (int or float)
          node.type?(:send, :lvar, :ivar, :const)
        end
      end
    end
  end
end
