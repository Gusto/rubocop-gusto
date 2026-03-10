# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Disallow Class.new outside of class/module declarations to prevent Sorbet type errors
      #
      # When Class.new is invoked without an argument at the root scope or outside a class/module,
      # any methods defined within the block are attached to the root scope, causing spurious
      # Sorbet type errors where methods become private instance methods of Object.
      #
      # See: https://github.com/sorbet/sorbet/issues/3609
      #
      # @example
      #   # bad
      #   let(:dummy_class) do
      #     Class.new do
      #       def match?(request)
      #         42
      #       end
      #     end
      #   end
      #
      #   # good
      #   module MyModule
      #     class DummyClass
      #       def match?(request)
      #         42
      #       end
      #     end
      #   end
      #
      #   let(:dummy_class) { MyModule::DummyClass }
      #
      #   # also good - Class.new with a superclass argument
      #   module MyModule
      #     let(:dummy_class) do
      #       Class.new(BaseClass) do
      #         def match?(request)
      #           42
      #         end
      #       end
      #     end
      #   end
      class ClassNewOutsideNamespace < Base
        MSG = "Do not use Class.new outside of a class/module declaration. " \
              "Define a proper class inside a module/class to avoid Sorbet type errors " \
              "where methods become attached to the root scope. See https://github.com/sorbet/sorbet/issues/3609"

        def on_block(node)
          return unless class_new_call?(node.send_node)
          return if inside_class_or_module?(node)

          add_offense(node.send_node)
        end

        alias_method :on_itblock, :on_block

        private

        def class_new_call?(node)
          return false unless node&.send_type?

          node.receiver&.const_type? &&
            node.receiver.const_name == "Class" &&
            node.method?(:new)
        end

        def inside_class_or_module?(node)
          node.each_ancestor(:class, :module).any?
        end
      end
    end
  end
end
