# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for class or module definitions inside factory directories.
      # Factory files are `require`d once at startup and are not reloaded by
      # Rails' code reloader. Constants defined inside them become stale
      # between reloads or cause "already initialized constant" warnings when
      # the test suite is run more than once in the same process.
      # Move shared test helpers to `spec/support/` instead.
      #
      # @example
      #   # bad — spec/factories/users.rb
      #   module UserHelpers
      #     def admin_user = create(:user, role: :admin)
      #   end
      #
      #   FactoryBot.define { factory :user }
      #
      #   # good — move the module out of the factory directory
      #   # spec/support/user_helpers.rb
      #   module UserHelpers
      #     def admin_user = create(:user, role: :admin)
      #   end
      #
      #   # spec/factories/users.rb
      #   FactoryBot.define { factory :user }
      #
      class FactoryClassesOrModules < Base
        MSG = "Do not define modules or classes in factory directories - they break reloading"

        def on_class(node)
          add_offense(node)
        end

        def on_module(node)
          add_offense(node)
        end
      end
    end
  end
end
