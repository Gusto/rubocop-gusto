# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags installation of discouraged gems (e.g., timecop) in Gemfiles and gemspecs.
      #
      # Configuration:
      #   Gems:
      #     timecop: "Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop."
      #
      # This cop is intended to be enabled in Rails projects via config/rails.yml.
      class DiscouragedGem < Base
        MSG = "Avoid using the '%{gem}' gem. %{advice}"

        RESTRICT_ON_SEND = %i(gem add_dependency add_development_dependency).freeze

        def on_send(node)
          check_gem_usage(node)
        end

        private

        def check_gem_usage(node)
          gem_name = extract_gem_name(node)
          return unless discouraged_gems.include?(gem_name)

          add_offense(node, message: message_for(gem_name))
          # No autocorrect: removing dependencies is a project decision.
        end

        def discouraged_gems
          gems_config.keys.map(&:to_s)
        end

        def advice_for(gem)
          gems_config[gem]
        end

        def gems_config
          cop_config["Gems"] || {}
        end

        def message_for(gem)
          format(MSG, gem: gem, advice: advice_for(gem))
        end

        def extract_gem_name(node)
          arg = node.first_argument
          return unless arg

          case arg.type
          when :str, :sym
            arg.value.to_s
          end
        end
      end
    end
  end
end
