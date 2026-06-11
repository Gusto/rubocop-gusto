# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Disallow defining classes or modules in factory directories. They break
      # Rails autoloading/reloading; define shared helpers outside the factories.
      #
      # @example
      #   # bad
      #   # spec/factories/users.rb
      #   class UserHelper
      #   end
      #
      #   FactoryBot.define do
      #     factory :user
      #   end
      #
      #   # good
      #   # spec/factories/users.rb
      #   FactoryBot.define do
      #     factory :user
      #   end
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
