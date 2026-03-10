# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags class or module definitions inside FactoryBot factory directories.
      #
      # Factory files are sometimes +load+ed rather than +require+d (e.g., by FactoryBot
      # auto-discovery). Loading a file multiple times causes Ruby to emit
      # constant-redefinition warnings and can produce subtle test isolation bugs.
      # Shared helpers or base classes used by factories should live in spec/support,
      # where they are safely required once.
      #
      # @example bad
      #   # spec/factories/users.rb
      #   module UserHelpers; end
      #   FactoryBot.define { factory :user }
      #
      # @example good
      #   # spec/support/user_helpers.rb — required once via rails_helper
      #   module UserHelpers; end
      #
      #   # spec/factories/users.rb — factory definitions only
      #   FactoryBot.define { factory :user }
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
