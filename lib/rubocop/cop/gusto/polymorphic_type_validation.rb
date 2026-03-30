# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks that every polymorphic `belongs_to` has a corresponding type
      # validation using `validates … inclusion: { in: … }` or the
      # `polymorphic_methods_for` helper. Without this validation Tapioca
      # (Sorbet's RBI generator) cannot determine which concrete types a
      # polymorphic association may hold, producing overly-wide or incorrect
      # type signatures.
      #
      # Using `allow_blank: true` on the type validation is also flagged
      # because it makes the type field optional, which breaks Sorbet's
      # assumption that the association is always typed.
      #
      # @example
      #   # bad — no type validation
      #   class Contract < ApplicationRecord
      #     belongs_to :subscriber, polymorphic: true
      #   end
      #
      #   # bad — allow_blank breaks Sorbet type inference
      #   class Contract < ApplicationRecord
      #     VALID_TYPES = [Employee.polymorphic_name].freeze
      #     belongs_to :subscriber, polymorphic: true
      #     validates :subscriber_type, inclusion: { in: VALID_TYPES },
      #                                 allow_blank: true
      #   end
      #
      #   # good — explicit inclusion validation
      #   class Contract < ApplicationRecord
      #     VALID_TYPES = T.let(
      #       [Employee.polymorphic_name, Contractor.polymorphic_name].freeze,
      #       T::Array[String]
      #     )
      #     belongs_to :subscriber, polymorphic: true
      #     validates :subscriber_type, inclusion: { in: VALID_TYPES }
      #   end
      #
      #   # good — using the polymorphic_methods_for helper
      #   class Contract < ApplicationRecord
      #     VALID_TYPES = T.let(
      #       [Employee.polymorphic_name, Contractor.polymorphic_name].freeze,
      #       T::Array[String]
      #     )
      #     belongs_to :subscriber, polymorphic: true
      #     polymorphic_methods_for :subscriber, VALID_TYPES
      #   end
      #
      class PolymorphicTypeValidation < Base
        RESTRICT_ON_SEND = %i[belongs_to validates polymorphic_methods_for].freeze

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
          has_validation, has_allow_blank = check_validations(node, type_field, relation_name)

          if has_allow_blank
            add_offense(node, message: ALLOW_BLANK_MSG)
          elsif !has_validation
            add_offense(node)
          end
        end

        private def check_validations(node, type_field, relation_name)
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

          [has_validation, has_allow_blank]
        end
      end
    end
  end
end
