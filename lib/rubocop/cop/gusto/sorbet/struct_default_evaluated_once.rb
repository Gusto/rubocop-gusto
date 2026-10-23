# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Sorbet
        # Flags `const` / `prop` declarations whose `default:` reads the clock or a random source.
        #
        # `T::Struct` evaluates `default:` once, when the class body runs, so every instance built
        # without the field shares the value from when the class loaded: the process's boot time,
        # or a single uuid. `factory:` runs for each instance.
        #
        # Calls inside a block or lambda passed as the default are left alone, since they run
        # when the block is called rather than when the class loads.
        #
        # @safety
        #   This cop's autocorrect is unsafe because it changes the value a field defaults to:
        #   each instance gets a fresh value instead of the one computed at load time.
        #   That is almost always the intent, but it is a behavior change.
        #
        # @example
        #   # bad
        #   const :started_at, Time, default: Time.zone.now
        #   const :uuid, String, default: SecureRandom.uuid
        #
        #   # good
        #   const :started_at, Time, factory: -> { Time.zone.now }
        #   const :uuid, String, factory: -> { SecureRandom.uuid }
        #
        #   # good - deterministic defaults are safe to evaluate once
        #   const :amount, BigDecimal, default: BigDecimal("0")
        #   const :timeout, ActiveSupport::Duration, default: 1.day
        class StructDefaultEvaluatedOnce < Base
          extend AutoCorrector

          MSG = "`default:` is evaluated once, when the class loads, so every instance shares this value. " \
                "Use `factory: -> { %{value} }` to compute it per instance."

          RESTRICT_ON_SEND = %i(const prop).freeze

          RELATIVE_TO_NOW_METHODS = %i(ago from_now since after before until).freeze

          # @!method clock_or_random_call?(node)
          def_node_matcher :clock_or_random_call?, <<~PATTERN
            {
              (send (const {nil? cbase} :Time) {:now :current})
              (send (send (const {nil? cbase} :Time) :zone) {:now :today :yesterday :tomorrow})
              (send (const {nil? cbase} {:Date :DateTime}) {:now :current :today :yesterday :tomorrow})
              (send (const {nil? cbase} {:SecureRandom :Random}) ...)
              (send nil? :rand ...)
            }
          PATTERN

          # Only receiverless `const`/`prop` calls are struct field declarations.
          def on_send(node)
            return unless node.receiver.nil?

            options = node.last_argument
            return unless options&.hash_type?

            default_pair = options.pairs.find { |pair| pair.key.sym_type? && pair.key.value == :default }
            return unless default_pair && evaluated_per_call?(default_pair.value)

            value_source = default_pair.value.source
            add_offense(default_pair, message: format(MSG, value: value_source)) do |corrector|
              corrector.replace(default_pair, "factory: -> { #{value_source} }")
            end
          end
          alias_method :on_csend, :on_send

          private

          def evaluated_per_call?(node)
            return false if node.any_block_type?
            return true if node.send_type? && (clock_or_random_call?(node) || relative_to_now?(node))

            node.each_child_node.any? { |child| evaluated_per_call?(child) }
          end

          # `1.day.ago` reads the clock; `1.day.ago(some_time)` does not.
          def relative_to_now?(node)
            RELATIVE_TO_NOW_METHODS.include?(node.method_name) && node.receiver && !node.arguments?
          end
        end
      end
    end
  end
end
