# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags installation of discouraged gems (e.g., timecop) in Gemfiles and gemspecs.
      #
      # Configuration:
      #   Gems: ['timecop']
      #   MessagePerGem:
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
          return unless gem_name
          return unless discouraged_gems.include?(gem_name)

          add_offense(node, message: message_for(gem_name))
          # No autocorrect: removing dependencies is a project decision.
        end

        def discouraged_gems
          Array(cop_config["Gems"]).map(&:to_s)
        end

        def advice_for(gem)
          per = cop_config["MessagePerGem"] || {}
          per[gem] || "Prefer built-in or agreed-upon alternatives in this codebase."
        end

        def message_for(gem)
          format(MSG, gem: gem, advice: advice_for(gem))
        end

        def extract_gem_name(node)
          case node.method_name
          when :gem
            first_literal_string(node)
          when :add_dependency, :add_development_dependency
            first_literal_string(node)
          else
            nil
          end
        end

        def first_literal_string(node)
          arg = node.first_argument
          return unless arg

          case arg.type
          when :str then arg.value.to_s
          when :sym then arg.value.to_s
          else nil
          end
        end
      end
    end
  end
end
