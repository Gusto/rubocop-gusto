# frozen_string_literal: true

require_relative "id_description_concerns"

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Ensures ID type arguments on mutations and input objects follow the standardized description template:
        # "The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>"
        # "The identifiers of each <ObjectName> (`<ObjectName.fieldName>`) to <action>" (for arrays)
        #
        # This cop only applies to arguments on mutations and input objects,
        # NOT on regular GraphQL objects/queries (see IdFieldArgumentDescription for those).
        #
        # @example Bad
        #   class UpdateEmployeeMutation < BaseMutation
        #     argument :employee_id, ID, 'Employee ID', required: true
        #   end
        #
        # @example Good
        #   class UpdateEmployeeMutation < BaseMutation
        #     argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to update', required: true
        #   end
        #
        #   class DeleteEmployeeInput < BaseInputObject
        #     argument :employee_ids, [ID], 'The identifiers of each Employee (`Employee.id`) to delete', required: true
        #   end
        #
        class IdInputArgumentDescription < Base
          include IdDescriptionConcerns

          MSG = "ID argument description should match template: " \
                "'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'."

          RESTRICT_ON_SEND = %i(argument).freeze

          # Single: "The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>"
          # Also supports multiple types joined by " or ":
          # "The identifier of the Employee (`Employee.id`) or Contractor (`Contractor.id`) to <action>"
          # The action can be any verb phrase (update, delete, add items to, etc.)
          TYPE_REF = /\w+ \(`\w+\.\w+`\)/
          SINGLE_PATTERN = /\AThe identifier of the #{TYPE_REF}(?: or #{TYPE_REF})* to \w+/

          # Array: "The identifiers of each <ObjectName> (`<ObjectName.fieldName>`) to <action>"
          ARRAY_PATTERN = /\AThe identifiers of each #{TYPE_REF}(?: or #{TYPE_REF})* to \w+/

          def on_send(node)
            # Only check if we're in a mutation or input object context
            return unless in_mutation_or_input_object?(node)

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
            pattern = is_array ? ARRAY_PATTERN : SINGLE_PATTERN
            pattern.match?(desc)
          end
        end
      end
    end
  end
end
