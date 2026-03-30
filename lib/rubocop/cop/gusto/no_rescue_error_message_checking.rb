# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for conditional logic inside `rescue` blocks that inspects
      # the exception's message string (via `match?`, `include?`, or `==`).
      # This is brittle: message strings are implementation details that can
      # change between library versions, and they often vary between database
      # adapters or other runtime environments. Rescue a specific exception
      # class instead.
      #
      # @see https://github.com/rubocop/rubocop/pull/13352
      #
      # @example
      #
      #   # bad
      #   begin
      #     something
      #   rescue => e
      #     if e.message.match?(/Duplicate entry/)
      #       handle_error
      #     end
      #   end
      #
      #  # bad
      #  begin
      #    something
      #  rescue => e
      #    unless e.message.match?(/Duplicate entry/)
      #      handle_error
      #    end
      #  end
      #
      #   # good
      #   begin
      #     something
      #   rescue ActiveRecord::RecordNotUnique => e
      #     handle_error
      #   end
      #
      class NoRescueErrorMessageChecking < Base
        MSG = "Avoid checking error message while handling exceptions. This is brittle and can break easily."
        METHODS_TO_CHECK = %i[match? include? ==].to_set.freeze

        def on_rescue(node)
          node.resbody_branches.last.each_descendant(:if, :unless).each do |condition_node|
            add_offense(condition_node) if message_check?(condition_node)
          end
        end

        private def message_check?(condition_node)
          return unless condition_node.condition.send_type?
          return unless condition_node.condition.receiver
          return unless METHODS_TO_CHECK.include?(condition_node.condition.method_name)

          if condition_node.condition.method?(:==)
            (condition_node.condition.receiver.str_type? && condition_node.condition.first_argument.method?(:message)) ||
              (condition_node.condition.receiver.send_type? && condition_node.condition.receiver.method?(:message))
          else
            condition_node.condition.receiver.type?(:send, :regexp, :array)
          end
        end
      end
    end
  end
end
