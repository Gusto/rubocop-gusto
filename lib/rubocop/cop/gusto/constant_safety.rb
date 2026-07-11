# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags safe navigation (`&.`) called on a constant, covering both
      # class/module constants (`Model&.find`) and SCREAMING_CASE constants
      # (`CONST&.each`).
      #
      # A constant reference is never `nil`, an undefined constant raises
      # `NameError` before the call is even attempted, so the safe navigation
      # operator is always redundant. Use the plain `.` operator instead.
      #
      # @example
      #   # bad
      #   Model&.find(id)
      #   ENTITY_TYPES&.each { |type| type.to_s }
      #   Foo::Bar&.call
      #   ::Foo&.call
      #
      #   # good
      #   Model.find(id)
      #   ENTITY_TYPES.each { |type| type.to_s }
      #   Foo::Bar.call
      #   ::Foo.call
      class ConstantSafety < Base
        extend AutoCorrector

        MSG = "Do not use safe navigation (`&.`) on a constant; constants are never `nil`, so use `.` instead."

        def on_csend(node)
          return unless node.receiver.const_type?

          add_offense(node.loc.dot) do |corrector|
            corrector.replace(node.loc.dot, ".")
          end
        end
      end
    end
  end
end
