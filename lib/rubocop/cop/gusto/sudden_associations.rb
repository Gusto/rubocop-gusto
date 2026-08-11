# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Detects Rails association definitions called on other classes from outside their class bodies.
      # This kind of sudden monkey-patching can lead to unexpected behavior.
      #
      # @example
      #   # bad
      #   Company.has_one :onboarding_benefits_survey
      #   User.belongs_to :company
      #   Post.has_many :comments
      #   Student.has_and_belongs_to_many :courses
      #
      #   # good
      #   class Company
      #     has_one :onboarding_benefits_survey
      #   end
      #
      #   class User
      #     belongs_to :company
      #   end
      class SuddenAssociations < Base
        MSG = "Do not define Rails associations on another class. Associations should only be defined within the class body of their model."
        RESTRICT_ON_SEND = %i(
          has_one
          has_many
          belongs_to
          has_and_belongs_to_many
        ).freeze

        # Matches association method calls on a class constant
        # Examples matched:
        #   Company.has_one :onboarding_benefits_survey
        #   User.belongs_to :company
        #   ::Company.has_many :users
        def on_send(node)
          return unless node.receiver
          return unless node.receiver.const_type?

          add_offense(node)
        end
      end
    end
  end
end
