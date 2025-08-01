# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
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
