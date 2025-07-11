# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks and discourages the use of metaprogramming techniques that make code harder to
      # understand, debug, and maintain.
      #
      # @example
      #
      #   # bad - using define_method
      #   define_method(:my_method) do |arg|
      #     puts arg
      #   end
      #
      #   # good - using regular method definition
      #   def my_method(arg)
      #     puts arg
      #   end
      #
      #   # bad - using instance_eval
      #   object.instance_eval do
      #     def foo
      #       bar
      #     end
      #   end
      #
      #   # good - defining methods on the class
      #   class MyClass
      #     def foo
      #       bar
      #     end
      #   end
      #
      #   # bad - using method_missing
      #   def method_missing(method, *args)
      #     if method.to_s.start_with?('find_by_')
      #       # ...
      #     end
      #   end
      #
      #   # bad - using define_singleton_method
      #   object.define_singleton_method(:foo) { bar }
      #
      #   # good - define class methods directly
      #   def self.foo
      #     bar
      #   end
      #
      #   # bad - using class_eval
      #   MyClass.class_eval do
      #     def foo
      #       bar
      #     end
      #   end
      #
      class NoMetaprogramming < Base
        RESTRICT_ON_SEND = %i(define_method instance_eval define_singleton_method class_eval).freeze

        # @!method included_definition?(node)
        def_node_matcher :included_definition?, <<~PATTERN
          (defs self :included ...)
        PATTERN

        # @!method inherited_definition?(node)
        def_node_matcher :inherited_definition?, <<~PATTERN
          (defs self :inherited ...)
        PATTERN

        # @!method using_method_missing?(node)
        def_node_matcher :using_method_missing?, <<~PATTERN
          (def :method_missing ...)
        PATTERN

        # @!method using_define_method?(node)
        def_node_matcher :using_define_method?, <<~PATTERN
          (send _ :define_method ...)
        PATTERN

        # @!method using_instance_eval?(node)
        def_node_matcher :using_instance_eval?, <<~PATTERN
          (send _ :instance_eval ...)
        PATTERN

        # @!method using_class_eval?(node)
        def_node_matcher :using_class_eval?, <<~PATTERN
          (send _ :class_eval ...)
        PATTERN

        # @!method using_define_singleton_method_on_klass_instance?(node)
        def_node_matcher :using_define_singleton_method_on_klass_instance?, <<~PATTERN
          (send _ :define_singleton_method ...)
        PATTERN

        def on_defs(node)
          included_definition?(node) do
            add_offense(node, message: 'self.included modifies the behavior of classes at runtime. Please avoid using if possible.')
          end

          inherited_definition?(node) do
            add_offense(node, message: 'self.inherited modifies the behavior of classes at runtime. Please avoid using if possible.')
          end
        end

        def on_def(node)
          using_method_missing?(node) do
            add_offense(node, message: 'Please do not use method_missing. Instead, explicitly define the methods you expect to receive.')
          end
        end

        def on_send(node)
          using_define_method?(node) do
            add_offense(node, message: 'Please do not define methods dynamically, instead define them using `def` and explicitly. This helps readability for both humans and machines.')
          end

          using_define_singleton_method_on_klass_instance?(node) do
            add_offense(node, message: 'Please do not use define_singleton_method. Instead, define the method explicitly using `def self.my_method; end`')
          end

          using_instance_eval?(node) do
            add_offense(node, message: 'Please do not use instance_eval to augment behavior onto an instance. Instead, define the method you want to use in the class definition.')
          end

          using_class_eval?(node) do
            add_offense(node, message: 'Please do not use class_eval to augment behavior onto a class. Instead, define the method you want to use in the class definition.')
          end
        end
      end
    end
  end
end
