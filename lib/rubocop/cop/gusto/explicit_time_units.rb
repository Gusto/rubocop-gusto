# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class ExplicitTimeUnits < Base
        MSG = 'Avoid adding/subtracting integers directly to Date/Time/DateTime. ' \
          'Use explicit time methods instead (e.g., `.days`, `.hours`).'

        RESTRICT_ON_SEND = %i[+ - << >>].freeze

        # Allowed time unit methods (both singular and plural)
        TIME_UNIT_METHODS = %i[
          second seconds
          minute minutes
          hour hours
          day days
          week weeks
          month months
          year years
          fortnight fortnights
        ].freeze

        def on_send(node)
          return unless date_time_arithmetic?(node)
          return if using_time_unit_method?(node)

          add_offense(node)
        end

        private

        def date_time_arithmetic?(node)
          receiver = node.receiver
          return false unless receiver

          # Check if receiver is a Date/Time/DateTime type
          return false unless date_time_type?(receiver)

          # Check if argument exists and is an integer (literal or variable)
          argument = node.first_argument
          return false unless argument

          argument.int_type? || potentially_integer?(argument)
        end

        def using_time_unit_method?(node)
          argument = node.first_argument
          return false unless argument

          # Check if the argument is a method call with a time unit method
          # e.g., 5.days, 3.hours, variable.weeks
          argument.send_type? && TIME_UNIT_METHODS.include?(argument.method_name)
        end

        def date_time_type?(node)
          # Check for explicit class names (const nodes)
          if node.const_type?
            const_name = node.source
            return true if %w[Date Time DateTime].include?(const_name)
          end

          # Check for send nodes that are class methods
          if node.send_type?
            # Handle DateTime.now, Date.today, etc.
            if node.receiver&.const_type?
              receiver_name = node.receiver.source
              return true if %w[Date Time DateTime].include?(receiver_name)
            end

            # Check for method calls that likely return date/time objects
            return true if date_time_method?(node.method_name)
          end

          false
        end

        def date_time_method?(method_name)
          %i[now today yesterday tomorrow current beginning_of_day
             end_of_day at_beginning_of_day at_end_of_day
             beginning_of_week end_of_week beginning_of_month end_of_month
             beginning_of_year end_of_year
             parse strptime xmlschema iso8601].include?(method_name)
        end

        def potentially_integer?(node)
          # Only flag if it's NOT using a time unit method
          return false if node.send_type? && TIME_UNIT_METHODS.include?(node.method_name)

          # Variable or method call that might be an integer
          # But NOT a float
          return false if node.float_type?

          node.send_type? || node.lvar_type? || node.ivar_type? || node.const_type?
        end
      end
    end
  end
end
