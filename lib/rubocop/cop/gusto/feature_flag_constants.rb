# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Enforces that `FeatureFlag.active?` is called with a constant rather than a
      # string literal. Defining flag keys as constants keeps them in one place,
      # makes typos a load-time error instead of a silent always-off flag, and lets
      # tools find every reference to a flag.
      #
      # `FeatureFlag` is a constant, so it is never nil and safe navigation
      # (`FeatureFlag&.active?`) is never used; the cop only handles `on_send`.
      #
      # @example
      #   # bad
      #   FeatureFlag.active?("some_feature_flag")
      #
      #   # good
      #   FeatureFlag.active?(SomeModule::SOME_FEATURE_FLAG)
      class FeatureFlagConstants < Base
        MSG = "FeatureFlag keys should be constants, not strings"
        RESTRICT_ON_SEND = %i(active?).freeze

        # @!method feature_flag_with_string?(node)
        def_node_matcher :feature_flag_with_string?, <<~PATTERN
          (send (const nil? :FeatureFlag) :active? (str _) ...)
        PATTERN

        def on_send(node)
          add_offense(node) if feature_flag_with_string?(node)
        end
      end
    end
  end
end
