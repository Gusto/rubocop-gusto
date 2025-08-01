# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Identifies uses of `Object#in?`, which iterates over each
      # item in a `Range` to see if a specified item is there. In contrast,
      # `Range#cover?` simply compares the target item with the beginning and
      # end points of the `Range`. In a great majority of cases, this is what
      # is wanted.
      #
      # @safety
      # This cop is unsafe. Here is an example of a case where `Range#cover?`
      # may not provide the desired result:
      #
      #  ('a'..'z').cover?('yellow') # => true
      #
      class ObjectIn < Base
        MSG = "Use `Range#cover?` instead of `Object#in?`."
        RESTRICT_ON_SEND = [:in?].freeze

        # @!method object_in(node)
        def_node_matcher :object_in, <<-PATTERN
          (call _ :in? {range (begin range)})
        PATTERN

        def on_send(node)
          return unless object_in(node)

          add_offense(node)
        end
        alias_method :on_csend, :on_send
      end
    end
  end
end
