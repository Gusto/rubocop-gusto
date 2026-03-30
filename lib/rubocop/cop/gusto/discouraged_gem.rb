# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags installation of gems that have been explicitly discouraged in
      # favor of a preferred alternative. The set of discouraged gems and the
      # advice message for each is configurable via the `Gems` option.
      # Rails projects should enable this cop via `config/rails.yml`, which
      # ships a default `Gems` list (e.g. banning `timecop`).
      #
      # @example Gems: { timecop: "Use Rails' time helpers instead." }
      #   # bad — Gemfile
      #   gem 'timecop'
      #   gem :timecop
      #
      #   # bad — .gemspec
      #   spec.add_dependency 'timecop'
      #   spec.add_development_dependency 'timecop', '~> 0.9'
      #
      #   # good — Gemfile
      #   # (use freeze_time or travel_to from Rails instead)
      #
      class DiscouragedGem < Base
        MSG = "Avoid using the '%<gem>s' gem. %<advice>s"

        RESTRICT_ON_SEND = %i[gem add_dependency add_development_dependency].freeze

        def on_send(node)
          check_gem_usage(node)
        end

        private def check_gem_usage(node)
          return unless node.first_argument&.type?(:str, :sym)
          return unless discouraged_gems.include?(node.first_argument.value.to_s)

          add_offense(node, message: message_for(node.first_argument.value.to_s))
          # No autocorrect: removing dependencies is a project decision.
        end

        private def discouraged_gems
          @discouraged_gems ||= gems_config.keys.map(&:to_s)
        end

        private def message_for(gem)
          format(MSG, gem: gem, advice: advice_for(gem))
        end

        private def advice_for(gem)
          gems_config[gem]
        end

        private def gems_config
          cop_config["Gems"] || {}
        end
      end
    end
  end
end
