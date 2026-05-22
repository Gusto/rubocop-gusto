# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for direct references to the `Datadog` constant. Call sites
      # should use an internal wrapper library so that the underlying
      # instrumentation provider can be swapped without touching application
      # code. Direct usage is permitted in the Datadog initializer and its
      # supporting library files.
      #
      # @example
      #   # bad
      #   Datadog::Statsd.new('localhost', 8125)
      #   Datadog.configure { |c| c.use :rails }
      #
      #   # good
      #   Monitoring.increment('my.counter')  # via the internal wrapper
      #
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
