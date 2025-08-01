# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Do not call a private method via __send__
      #
      # @example
      #   # bad
      #   foo.__send__(:bar)
      #   __send__(:run_baz)
      #
      #   # good
      #   There's no better alternative, don't call private methods.
      #
      class NoSend < Base
        MSG = "Do not call a private method via `__send__`."
        RESTRICT_ON_SEND = %i(__send__).freeze

        # @!method invoke_private_method_send?(node)
        def_node_matcher :invoke_private_method_send?, <<~PATTERN
          (call _ :__send__ (sym _))
        PATTERN

        def on_send(node)
          invoke_private_method_send?(node) { add_offense(node) }
        end
        alias_method :on_csend, :on_send
      end
    end
  end
end
