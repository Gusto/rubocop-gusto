# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class FactoryClassesOrModules < Base
        MSG = 'Do not define modules or classes in factory directories - they break reloading'

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
