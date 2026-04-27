# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # NOTE: Being pushed upstream here: https://github.com/rubocop/rubocop-rails/pull/1375
      # Checks for usage of `Rails.env` which can be replaced with Feature Flags
      #
      # Although `local?` is a form of an environment-specific check, it is allowed because
      # it cannot be used to control overall environment rollout, but it can be helpful to
      # distinguish or protect code that is explicitly written to only ever execute in a
      # dev or test environment. `local?` is also a form of a feature flag.
      #
      # @example
      #
      #   # bad
      #   Rails.env.production? || Rails.env.demo?
      #
      #   # good
      #   if FeatureFlag.enabled?(:new_feature)
      #     # new feature code
      #   end
      #
      #   # good
      #   raise unless Rails.env.local?
      #
      #   # good
      #   abort ("The Rails environment is running in production mode!") unless Rails.env.local?
      #
      class RailsEnv < Base
        # This allow list is derived from:
        # (Rails.env.methods - Object.instance_methods).select { |m| m.to_s.end_with?('?') }
        # and then removing the environment specific methods like development?, test?, production?
        ALLOWED_LIST = Set.new(
          %i(
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
          )
        ).freeze
        MSG = "Use Feature Flags or config instead of `Rails.env`."
        RESTRICT_ON_SEND = %i(env).freeze

        # @!method prohibited_rails_env?(node)
        def_node_matcher :prohibited_rails_env?, <<~PATTERN
          (send
            (send (const _ :Rails) :env)
            #prohibited_predicate?
          )
        PATTERN

        def on_send(node)
          return unless node.receiver&.const_name == "Rails"

          add_offense(node.parent) if prohibited_rails_env?(node.parent)
        end

        private

        def prohibited_predicate?(name)
          name.to_s.end_with?("?") && !ALLOWED_LIST.include?(name)
        end
      end
    end
  end
end
