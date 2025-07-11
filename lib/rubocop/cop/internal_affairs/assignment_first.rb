# frozen_string_literal: true

module RuboCop
  module Cop
    module InternalAffairs
      # Check for assignment as the first action in a cop hook.
      #
      # @example
      #   # bad
      #   def on_send(node)
      #     foo = 1
      #     do_something
      #   end
      #
      #   # good
      #   def on_send(node)
      #     do_something
      #     foo = 1
      #   end
      #
      class AssignmentFirst < Base
        HOOKS = %i(
          on_def
          on_defs
          on_send
          on_csend
          on_const
          on_int
          on_class
          on_module
          on_block
          on_begin
          on_kwbegin
          after_int
          after_def
          after_send
          after_csend
          after_class
          after_module
        ).to_set.freeze
        MSG = 'Avoid placing an assignment as the first action in `%{hook}`.'

        def on_def(node)
          return unless HOOKS.include?(node.method_name)
          return unless node.body

          # Look through a begin node, e.g. look inside parentheses
          first_child = node.body.begin_type? ? node.body.children.first : node.body
          return unless first_child&.assignment?

          add_offense(first_child, message: format(MSG, hook: node.method_name))
        end
      end
    end
  end
end
