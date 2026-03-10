# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Ensures every +belongs_to ..., polymorphic: true+ has a corresponding inclusion
      # validation on its type column, or uses +polymorphic_methods_for+.
      #
      # Without a type validation, the polymorphic type column can be set to an arbitrary
      # string, which causes two problems:
      #   1. Tapioca cannot enumerate the possible types and generates incorrect Sorbet types.
      #   2. Silent data integrity issues when an invalid type is persisted.
      #
      # Two valid patterns are accepted:
      #   - +validates :foo_type, inclusion: { in: VALID_TYPES }+ (universal)
      #   - +polymorphic_methods_for :foo, VALID_TYPES+ (ZP/HI codebase only)
      #
      # +allow_blank: true+ on the type validation is also forbidden because it defeats
      # the inclusion check. Only applies to model files (see +Include+ in config/rails.yml).
      #
      # @example bad
      #   belongs_to :subscription_detail, polymorphic: true
      #
      # @example good
      #   VALID_TYPES = [Foo.polymorphic_name, Bar.polymorphic_name].freeze
      #   belongs_to :subscription_detail, polymorphic: true
      #   validates :subscription_detail_type, presence: true, inclusion: { in: VALID_TYPES }
      class PolymorphicTypeValidation < Base
        RESTRICT_ON_SEND = %i(belongs_to validates polymorphic_methods_for).freeze

        MSG = <<~MESSAGE
          Polymorphic relations must validate their corresponding type field with "validates .. inclusion: { in: .. }", or using polymorphic_methods_for

          Example:
            # bad
            belongs_to :subscription_detail, polymorphic: true

            # good
            VALID_TYPES = T.let([LidiSubscriptionDetail.polymorphic_name, LegacyActiveBenefits::VoluntaryLifeSubscriptionDetail.polymorphic_name].freeze, T::Array[String])
            belongs_to :subscription_detail, polymorphic: true
            validates :subscription_detail_type, presence: true, inclusion: { in: VALID_TYPES }

            # also good (in ZP/HI, at least)
            include PolymorphicCallable
            VALID_TYPES = T.let([LidiSubscriptionDetail.polymorphic_name, LegacyActiveBenefits::VoluntaryLifeSubscriptionDetail.polymorphic_name].freeze, T::Array[String])
            belongs_to :subscription_detail, polymorphic: true
            polymorphic_methods_for :subscription_detail, VALID_TYPES
        MESSAGE

        ALLOW_BLANK_MSG = "Polymorphic type validations cannot use allow_blank: true"

        # @!method polymorphic_relation?(node)
        def_node_matcher :polymorphic_relation?, <<~PATTERN
          (send nil? :belongs_to _ (hash <(pair (sym :polymorphic) (true)) ...>))
        PATTERN

        # @!method type_validation?(node)
        def_node_matcher :type_validation?, <<~PATTERN
          (send nil? :validates (sym _) (hash <#inclusion_in? ...>))
        PATTERN

        # @!method inclusion_in?(node)
        def_node_matcher :inclusion_in?, <<~PATTERN
          (pair (sym :inclusion) (hash <(pair (sym :in) _) ...>))
        PATTERN

        # @!method polymorphic_methods_for?(node)
        def_node_matcher :polymorphic_methods_for?, <<~PATTERN
          (send nil? :polymorphic_methods_for (sym _) _)
        PATTERN

        # @!method allow_blank?(node)
        def_node_matcher :allow_blank?, <<~PATTERN
          (pair (sym :allow_blank) (true))
        PATTERN

        def on_send(node)
          return unless polymorphic_relation?(node)

          relation_name = node.first_argument.value
          type_field = :"#{relation_name}_type"

          # Look for either a validation of the type field or polymorphic_methods_for
          has_validation = false
          has_allow_blank = false

          node.parent.each_node(:send) do |validation_node|
            if type_validation?(validation_node) && validation_node.first_argument.value == type_field
              has_validation = true
              # Check for allow_blank in the validation options
              validation_node.arguments[1].each_node(:pair) do |pair_node|
                has_allow_blank = true if allow_blank?(pair_node)
              end
            elsif polymorphic_methods_for?(validation_node) && validation_node.first_argument.value == relation_name
              has_validation = true
            end
          end

          if has_allow_blank
            add_offense(node, message: ALLOW_BLANK_MSG)
          elsif !has_validation
            add_offense(node)
          end
        end
      end
    end
  end
end
