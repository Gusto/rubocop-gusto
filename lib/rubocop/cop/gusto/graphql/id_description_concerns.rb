# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        module IdDescriptionConcerns
          # analytics_id is intentionally excluded
          PRIMARY_ID_FIELDS = %i(id uuid).freeze

          # Matches a GraphQL field declaration capturing name and type node.
          FIELD_CALL_PATTERN = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :field (sym $_name) $_ ...)
          PATTERN

          # Matches a GraphQL argument declaration capturing name and type node.
          ARGUMENT_CALL_PATTERN = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :argument (sym $_name) $_ ...)
          PATTERN

          # Mutation / input-object base classes conventionally end in one of these final
          # segments (e.g. `Base::PermissionedMutation`, `Gusto::GraphQL::Objects::BaseInputObject`,
          # `Base::Input`). We match on the base class's final name segment rather than a substring
          # of its source, so unrelated bases that merely *contain* the word (e.g.
          # `GraphQLMutationTool`, `MutationHelper`) are not misclassified.
          MUTATION_OR_INPUT_BASE_SUFFIXES = %w(Mutation InputObject Input).freeze

          def field_call?(node, &block)
            FIELD_CALL_PATTERN.match(node, &block)
          end

          def argument_call?(node, &block)
            ARGUMENT_CALL_PATTERN.match(node, &block)
          end

          private

          def id_type?(type_node)
            return false unless type_node
            return false unless type_node.const_type?

            const_name = type_node.const_name
            const_name == "ID" || const_name == "GraphQL::Types::ID"
          end

          def array_id_type?(type_node)
            return false unless type_node

            # Match: [ID] or [GraphQL::Types::ID]
            if type_node.array_type?
              inner = type_node.children.first
              return id_type?(inner)
            end

            false
          end

          def extract_description(node)
            description_from_positional_argument(node) ||
              description_from_keyword_argument(node) ||
              description_from_block(node)
          end

          def description_from_positional_argument(node)
            node.arguments.find(&:str_type?)&.value
          end

          def description_from_keyword_argument(node)
            node.each_child_node(:hash) do |arg|
              arg.each_pair do |key, value|
                return value.value if key.sym_type? && key.value == :description && value.str_type?
              end
            end

            nil
          end

          def description_from_block(node)
            parent = node.parent
            return nil unless parent&.block_type? && parent.send_node == node

            parent.body&.each_node(:send) do |send_node|
              if send_node.method?(:description) && send_node.first_argument&.str_type?
                return send_node.first_argument.value
              end
            end

            nil
          end

          # Find the GraphQL type name for the enclosing class or module
          # Prefers graphql_name declaration over Ruby class/module name
          # Returns nil if the name cannot be determined
          def find_graphql_type_name(node)
            # Try class first (most common), then module (for interfaces)
            type_node = node.each_ancestor(:class).first || node.each_ancestor(:module).first
            return nil unless type_node

            # Look for graphql_name declaration in the type body
            graphql_name = find_graphql_name_declaration(type_node)
            return graphql_name if graphql_name

            # Fall back to Ruby class/module name, stripping common suffixes
            # GraphQL-ruby automatically strips "Type" from class names
            # Interfaces conventionally use "Interface" suffix
            # Also strip module namespacing, only use the final name
            const_node = type_node.children.first
            return nil unless const_node

            full_name = const_node.const_name
            type_name = full_name.split("::").last
            strip_graphql_suffix(type_name)
          end

          def strip_graphql_suffix(name)
            name.chomp("Type").chomp("Interface")
          end

          def find_graphql_name_declaration(type_node)
            type_body = type_node.body
            return nil unless type_body

            nodes = type_body_nodes(type_body)
            graphql_name_call = find_graphql_name_call(nodes)
            return nil unless graphql_name_call

            first_arg = graphql_name_call.first_argument
            first_arg.value if first_arg&.str_type?
          end

          def type_body_nodes(type_body)
            if type_body.begin_type?
              type_body.children
            else
              [type_body]
            end
          end

          def find_graphql_name_call(nodes)
            nodes.find { |node| node.send_type? && node.method?(:graphql_name) }
          end

          def in_mutation_or_input_object?(node)
            node.each_ancestor(:class).any? do |class_node|
              base = class_node.parent_class
              next false unless base&.const_type?

              base.short_name.to_s.end_with?(*MUTATION_OR_INPUT_BASE_SUFFIXES)
            end
          end
        end
      end
    end
  end
end
