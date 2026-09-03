# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        class TypeVariables < Base
          MSG = "`type_member` and `type_template` in GraphQL objects must not be untyped. " \
            "The type here should match the type expected from the `object` method."

          UNTYPED_OBJECT = RuboCop::AST::NodePattern.new(<<-PATTERN)
            (block (send nil? {:type_member | :type_template}) (args) (hash (pair (sym :fixed) (send (const nil? :T) :untyped))))
          PATTERN

          def on_block(node)
            return unless UNTYPED_OBJECT.match(node)

            add_offense(node)
          end
          alias_method :on_numblock, :on_block
          alias_method :on_itblock, :on_block
        end
      end
    end
  end
end
