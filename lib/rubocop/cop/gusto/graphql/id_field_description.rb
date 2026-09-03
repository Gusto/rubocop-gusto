# frozen_string_literal: true

require_relative "id_description_concerns"

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Ensures ID type fields follow the standardized description template:
        # "The <ObjectName> identifier"
        #
        # This applies to fields named :id or :uuid with type ID.
        #
        # @example Bad
        #   field :id, ID, 'Unique identifier', null: false
        #   field :id, ID, null: false, description: 'The unique identifier'
        #
        # @example Good
        #   field :id, ID, 'The Employee identifier', null: false
        #   field :id, ID, null: false, description: 'The Employee identifier'
        #
        class IdFieldDescription < Base
          include IdDescriptionConcerns

          MSG = "ID field description should match template: 'The <ObjectName> identifier'."

          RESTRICT_ON_SEND = %i(field).freeze

          def on_send(node)
            field_call?(node) do |name, type_node|
              return unless id_type?(type_node) && PRIMARY_ID_FIELDS.include?(name)

              desc = extract_description(node)
              return if desc.nil? # No description - let other cops handle missing descriptions
              return if valid_field_description?(desc, node)

              suggested = expected_description(node)
              report_offense(node, suggested)
            end
          end

          private

          def expected_description(node)
            graphql_name = find_graphql_type_name(node)
            return nil if graphql_name.nil?

            "The #{graphql_name} identifier"
          end

          def valid_field_description?(desc, node)
            expected = expected_description(node)
            return false unless expected

            desc.start_with?(expected, "[REFERENCE ONLY] #{expected}")
          end

          def report_offense(node, suggested)
            if suggested
              add_offense(node, message: "#{MSG} Suggested: '#{suggested}'")
            else
              add_offense(node)
            end
          end
        end
      end
    end
  end
end
