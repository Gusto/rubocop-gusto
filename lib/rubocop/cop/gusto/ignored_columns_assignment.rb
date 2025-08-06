# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Enforces proper usage of `ignored_columns` assignment
      #
      # This cop ensures that `ignored_columns` is assigned using `+=` with an array
      # instead of direct assignment, which can cause issues with existing ignored columns.
      #
      # @example
      #
      #   # bad
      #   self.ignored_columns = :column_name
      #   self.ignored_columns = 'column_name'
      #   self.ignored_columns = [:column_name]
      #   self.ignored_columns = ['column_name']
      #
      #   # good
      #   self.ignored_columns += [:column_name]
      #   self.ignored_columns += ['column_name']
      #
      class IgnoredColumnsAssignment < Base
        MSG = 'Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.'
        RESTRICT_ON_SEND = %i(ignored_columns=).freeze

        # @!method ignored_columns_direct_assignment?(node)
        def_node_matcher :ignored_columns_direct_assignment?, <<~PATTERN
          (send (self) :ignored_columns= _)
        PATTERN

        def on_send(node)
          if ignored_columns_direct_assignment?(node)
            add_offense(node.loc.selector)
          end
        end
        alias_method :on_csend, :on_send
      end
    end
  end
end
