# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for the use of `min` or `max` with a proc. Corrects to `min_by` or `max_by`.
      #
      # @safety This cop is unsafe because it will change the behavior of the code.
      #
      # @example
      #  # bad
      #  arr = [[3, 3, 3], [2, 2], [1]]
      #  arr.min(&:count)
      #   => [3, 3, 3] - oh no how did this happen?
      #  arr = [[2,2],[1,1],[3,3,3]]
      #  arr.min &:first # => TypeError: no implicit conversion of Array into Integer
      #  arr = [[1, 1], [3, 3], [2, 2]]
      #  arr.max { |pair| pair.first } # => [2, 2] (semantically incorrect)
      #
      #  # good
      #  arr = [[2,2],[1],[3,3,3]]
      #  arr.min_by &:first # => [1]
      #  arr = [[1, 1], [3, 3], [2, 2]]
      #  arr.max_by { |pair| pair.first } # => [3, 3]
      #
      class MinByMaxBy < Base
        extend AutoCorrector

        MSG = 'Use `%{method}_by` instead of `%{method}` with a proc like `&:my_method_proc`. `%{method}` expects Comparable elements.'
        RESTRICT_ON_SEND = %i(min max).freeze

        def on_send(node)
          return unless node.arguments?
          return unless node.first_argument.block_pass_type?

          method_name = node.method_name
          add_offense(node, message: format(MSG, method: method_name)) do |corrector|
            corrector.replace(node, node.source.sub(method_name.to_s, "#{method_name}_by"))
          end
        end
        alias_method :on_csend, :on_send
      end
    end
  end
end
