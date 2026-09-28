# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Flags a GraphQL resolver that takes its target from the request context rather than from
        # its arguments or its parent `object`. Context may still default an omitted argument, from
        # the argument's `prepare:`, which runs before authorization.
        #
        # Flags nothing until `ResourceAccessors` lists the context methods that name a resource,
        # since every project's context class names them differently.
        #
        # @example ResourceAccessors: [company_uuid]
        #   # bad
        #   def resolve
        #     Company.find_by!(uuid: context.company_uuid)
        #   end
        #
        #   # good
        #   argument :company_uuid, ID, required: false, default_value: nil,
        #                               prepare: -> (value, ctx) { value.presence || ctx.company_uuid }
        #
        #   def resolve(company_uuid:)
        #     Company.find_by!(uuid: company_uuid)
        #   end
        class ResourceFromContext < Base
          MSG = "Take the target from an argument or `object`, not `%{source}`. To default an omitted " \
                "argument from context, fill it in the argument's `prepare:` and give it " \
                "`default_value: nil` so `prepare` runs."

          # @!method context_reference?(node)
          def_node_matcher :context_reference?, "{(send _ :context) (lvar {:context :ctx}) (ivar :@context)}"

          # @!method context_method_call?(node, names)
          def_node_matcher :context_method_call?, "(send nil? %1)"

          # @!method sorbet_wrapped(node)
          def_node_matcher :sorbet_wrapped, "(send (const nil? :T) {:cast :let} $_ ...)"

          # @!method prepare_option?(node)
          def_node_matcher :prepare_option?, "(pair (sym :prepare) _)"

          def on_new_investigation
            accessors = configured_names("ResourceAccessors")
            ast = processed_source.ast
            return if accessors.empty? || ast.nil?

            @context_methods = configured_names("ContextMethods")
            aliases = ast.each_node(:lvasgn).select { |assignment| context?(assignment.expression) }.map(&:name)
            ast.each_node(:call) do |read|
              next unless accessors.include?(read.method_name)
              next unless context?(read.receiver) || context_alias?(read.receiver, aliases)
              next if read.each_ancestor(:pair).any? { |pair| prepare_option?(pair) }

              add_offense(read, message: format(MSG, source: read.source))
            end
          end

          private

          def context?(node)
            wrapped = sorbet_wrapped(node)
            return context?(wrapped) if wrapped

            context_reference?(node) || context_method_call?(node, @context_methods)
          end

          def context_alias?(node, aliases)
            node&.lvar_type? && aliases.include?(node.children.first)
          end

          def configured_names(key)
            Array(cop_config[key]).to_set(&:to_sym)
          end
        end
      end
    end
  end
end
