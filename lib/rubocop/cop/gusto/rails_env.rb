# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for usage of `Rails.env` predicate methods that perform
      # environment-specific branching. Hard-coding environment names makes
      # it impossible to enable or disable behavior without a deployment,
      # and creates an ever-growing list of special cases. Use feature flags
      # or configuration values instead.
      #
      # `Rails.env.local?` is allowed because it is not an environment-
      # specific rollout mechanism — it only guards code that is explicitly
      # intended for development and test environments (e.g. raising early
      # on misconfiguration), and is itself a form of a feature flag.
      #
      # @example
      #   # bad
      #   Rails.env.production?
      #   Rails.env.production? || Rails.env.demo?
      #   if Rails.env.staging?
      #     do_something
      #   end
      #
      #   # good
      #   FeatureFlag.enabled?(:new_feature)
      #
      #   # good — local? is permitted
      #   raise unless Rails.env.local?
      #   abort('Running in production!') unless Rails.env.local?
      #
      # @see https://github.com/rubocop/rubocop-rails/pull/1375
      #
      class RailsEnv < Base
        # This allow list is derived from:
        # (Rails.env.methods - Object.instance_methods).select { |m| m.to_s.end_with?('?') }
        # and then removing the environment specific methods like development?, test?, production?
        ALLOWED_LIST = Set.new(
          %i[
            unicode_normalized?
            exclude?
            empty?
            acts_like_string?
            include?
            is_utf8?
            casecmp?
            match?
            starts_with?
            ends_with?
            start_with?
            end_with?
            valid_encoding?
            ascii_only?
            between?
            local?
          ],
        ).freeze
        MSG = "Use Feature Flags or config instead of `Rails.env`."
        PROHIBITED_CLASS = "Rails"
        RESTRICT_ON_SEND = %i[env].freeze

        def on_send(node)
          return unless node.receiver&.const_name == PROHIBITED_CLASS

          return unless (parent = node.parent)
          return unless parent.send_type?
          return unless parent.predicate_method?

          return if ALLOWED_LIST.include?(parent.method_name)

          add_offense(parent)
        end
      end
    end
  end
end
