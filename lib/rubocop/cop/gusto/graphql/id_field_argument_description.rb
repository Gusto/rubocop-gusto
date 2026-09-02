# frozen_string_literal: true

require_relative "id_description_concerns"

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Ensures ID type arguments on query fields follow the standardized description template:
        # "The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by"
        # "The identifiers of each <ObjectName> (`<ObjectName.fieldName>`) to filter by" (for arrays)
        #
        # This cop only applies to arguments on regular GraphQL objects/queries,
        # NOT on mutations or input objects (see IdInputArgumentDescription for those).
        #
        # @example Bad
        #   argument :employee_id, ID, 'Employee ID', required: true
        #
        # @example Good
        #   argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to filter by', required: true
        #   argument :employee_ids, [ID], 'The identifiers of each Employee (`Employee.id`) to filter by', required: true
        #
        class IdFieldArgumentDescription < Base
          include IdDescriptionConcerns

          MSG = "ID argument description should match template: " \
                "'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by'."

          RESTRICT_ON_SEND = %i(argument).freeze

          # A single "<ObjectName> (`<ObjectName.fieldName>`)" reference. Multiple may be joined
          # with " or " for arguments that accept an id from more than one entity.
          TYPE_REF = /\w+ \(`\w+\.\w+`\)/

          # Single: "The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by"
          SINGLE_PATTERN = /\AThe identifier of the #{TYPE_REF}(?: or #{TYPE_REF})* to filter by/

          # Array: "The identifiers of each <ObjectName> (`<ObjectName.fieldName>`) to filter by"
          ARRAY_PATTERN = /\AThe identifiers of each #{TYPE_REF}(?: or #{TYPE_REF})* to filter by/

          def on_send(node)
            # Skip if we're in a mutation or input object context because there's another cop for that
            return if in_mutation_or_input_object?(node)

            argument_call?(node) do |_name, type_node|
              is_array = array_id_type?(type_node)
              return unless id_type?(type_node) || is_array

              desc = extract_description(node)
              return if desc.nil? # No description - let other cops handle missing descriptions
              return if valid_argument_description?(desc, is_array)

              add_offense(node)
            end
          end

          private

          def valid_argument_description?(desc, is_array)
            # Only validate the pattern format, not the object name.
            # The object name should reference the actual GraphQL type,
            # which may differ from what we'd infer from the argument name.
            # e.g., argument :device_id could reference TrustedDevice type
            pattern = is_array ? ARRAY_PATTERN : SINGLE_PATTERN
            pattern.match?(desc)
          end
        end
      end
    end
  end
end
