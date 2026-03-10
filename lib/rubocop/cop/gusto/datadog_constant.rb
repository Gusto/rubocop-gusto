# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags direct references to the +Datadog+ constant outside of permitted locations.
      #
      # Direct Datadog calls must go through an internal wrapper library so that observability
      # instrumentation can be swapped or mocked without modifying call sites. Permitted
      # locations (initializers, lib/datadog, specs) are excluded in config/default.yml.
      #
      # To add a new exemption, extend the +Exclude+ list in your project's .rubocop.yml
      # rather than disabling the cop entirely.
      #
      # @example bad
      #   Datadog::Tracing.trace("operation")
      #
      # @example good
      #   # Use your project's internal observability wrapper instead
      #   Observability.trace("operation")
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
