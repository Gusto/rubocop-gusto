# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        class DefaultForOptionalArgument < Base
          MSG = "Please define a default value for optional arguments."

          # Matches a field block: (block (send nil? :field (sym NAME) ...) (args) BODY...)
          GET_FIELDS = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (block (send nil? :field (:sym $_) ...) (:args) $...)
          PATTERN

          # Matches an argument send node: (send nil? :argument (sym _) ...)
          GET_ALL_ARGUMENTS = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :argument (sym _) ...)
          PATTERN

          # Matches a required: false hash pair inside an argument node
          NON_REQUIRED_ARGUMENT = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (pair (sym :required) (:false))
          PATTERN

          # Matches an argument send node, capturing the argument name
          ARGUMENT_NAME = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :argument (sym $_) ...)
          PATTERN

          KWARG_NAME = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (kwarg $_)
          PATTERN

          KWARG_NODE = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (kwarg _)
          PATTERN

          def on_class(node)
            return unless node.children.last

            klass_body = node.children.last
            arguments = {
              resolve: collect_optional_arguments(klass_body),
            }.merge!(collect_field_arguments(klass_body))

            return if arguments.all? { |_k, v| v.empty? }

            required_kwargs = collect_required_kwargs(klass_body, arguments)
            return if required_kwargs.all? { |_k, v| v.nil? || v.empty? }

            mark_offenses(required_kwargs, arguments)
          end

          private

          def collect_optional_arguments(body)
            @collect_optional_arguments ||= body.each_descendant(:send).filter_map do |arg|
              ARGUMENT_NAME.match(arg) if GET_ALL_ARGUMENTS.match(arg) &&
                arg.each_descendant(:pair).any? { |pair| NON_REQUIRED_ARGUMENT.match(pair) }
            end
          end

          def collect_field_arguments(body)
            body.each_descendant(:block).each_with_object({}) do |field_node, optional_args|
              GET_FIELDS.match(field_node) do |field_name, _|
                collected = field_node.each_descendant(:send).filter_map do |n|
                  ARGUMENT_NAME.match(n) if GET_ALL_ARGUMENTS.match(n) &&
                    n.each_descendant(:pair).any? { |pair| NON_REQUIRED_ARGUMENT.match(pair) }
                end
                optional_args[field_name] = collected
              end
            end
          end

          def collect_required_kwargs(body, arguments)
            @method_arg_patterns ||= {}
            arguments.each_with_object({}) do |(method_name, _arg_name), hash|
              find_method_args_pattern = @method_arg_patterns[method_name] ||=
                RuboCop::AST::NodePattern.new("(def :#{method_name} (args $...) ...)")

              captured = body.each_descendant(:def).lazy.filter_map do |def_node|
                find_method_args_pattern.match(def_node)
              end.first
              hash[method_name] = captured&.select { |n| KWARG_NODE.match(n) }
            end
          end

          def mark_offenses(required_kwargs, optional_args)
            required_kwargs.each do |method, kwargs|
              kwargs&.each do |kwarg|
                name = KWARG_NAME.match(kwarg)
                add_offense(kwarg) if optional_args[method].include? name
              end
            end
          end
        end
      end
    end
  end
end
