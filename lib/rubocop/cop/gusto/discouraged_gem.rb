# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flag installation of discouraged gems (e.g. timecop) in Gemfiles and
      # gemspecs. The discouraged gems an advice about alternatives are configured under
      # `Gems:`; intended to be enabled in Rails projects via config/rails.yml.
      #
      # @example Gems: { timecop: "Use Rails' time helpers instead of Timecop." }
      #   # bad
      #   gem "timecop"
      #
      #   # good
      #   # Use Rails' time helpers (freeze_time, travel_to) instead.
      class DiscouragedGem < Base
        MSG = "Avoid using the '%{gem}' gem. %{advice}"

        RESTRICT_ON_SEND = %i(gem add_dependency add_development_dependency).freeze

        def on_send(node)
          check_gem_usage(node)
        end

        private

        def check_gem_usage(node)
          return unless node.first_argument&.type?(:str, :sym)
          return unless discouraged_gems.include?(node.first_argument.value.to_s)

          add_offense(node, message: message_for(node.first_argument.value.to_s))
          # No autocorrect: removing dependencies is a project decision.
        end

        def discouraged_gems
          @discouraged_gems ||= gems_config.keys.map(&:to_s)
        end

        def message_for(gem)
          format(MSG, gem:, advice: advice_for(gem))
        end

        def advice_for(gem)
          gems_config[gem]
        end

        def gems_config
          cop_config["Gems"] || {}
        end
      end
    end
  end
end
