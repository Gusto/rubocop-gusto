# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Disallow referencing the `Datadog` constant directly. Calls should go
      # through an approved wrapper library so instrumentation stays consistent
      # and swappable.
      #
      # @example
      #   # bad
      #   Datadog::Tracing.active_trace
      #
      #   # good
      #   Observability.active_trace
      class DatadogConstant < Base
        MSG = "Do not call Datadog directly, use an appropriate wrapper library."
        NAMESPACE = "Datadog"

        def on_const(node)
          add_offense(node) if node.const_name == NAMESPACE
        end
      end
    end
  end
end
