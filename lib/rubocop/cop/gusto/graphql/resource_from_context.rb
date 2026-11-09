# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Flags a GraphQL resolver that takes its target from the request context rather than from
        # its arguments or its parent `object`. The one sanctioned fallback is gusto-graphql's
        # `default_from_context:`, which defaults an omitted argument with no context read to flag.
        # A context read inside a hand-written `prepare:` is flagged, because it cannot be told apart
        # from an override that ignores the client's value.
        #
        # Flags nothing until `ResourceAccessors` lists the context methods that name a resource. A listed
        # name also covers its bang form (`company_id!`), which returns the same target, but not its
        # predicate form (`company_id?`), which returns a boolean.
        #
        # @example ResourceAccessors: [company_uuid]
        #   # bad
        #   def resolve
        #     Company.find_by!(uuid: context.company_uuid)
        #   end
        #
        #   # good
        #   argument :company_id, ID, as: :company_uuid
        #
        #   def resolve(company_uuid:)
        #     Company.find_by!(uuid: company_uuid)
        #   end
        #
        #   # good, for an existing field whose clients omit the argument
        #   argument :company_id, ID, required: false, as: :company_uuid, default_from_context: :company_uuid
        class ResourceFromContext < Base
          MSG = "Take the target from an argument or `object`, not `%{source}`; to default an omitted " \
                "argument, use `default_from_context:`. If it names who is asking, not what is acted on, " \
                "read it through a caller accessor kept off `ResourceAccessors`."

          LOCAL_SCOPES = %i(def defs block numblock).freeze

          # @!method context_reference?(node)
          def_node_matcher :context_reference?, "{(send _ :context) (lvar {:context :ctx}) (ivar :@context)}"

          # @!method context_method_call?(node, names)
          def_node_matcher :context_method_call?, "(send nil? %1)"

          # @!method sorbet_wrapped(node)
          def_node_matcher :sorbet_wrapped, "(send (const nil? :T) {:cast :let} $_ ...)"

          def on_new_investigation
            accessors = configured_names("ResourceAccessors").to_set { |name| accessor_name(name) }
            ast = processed_source.ast
            return if accessors.empty? || ast.nil?

            @context_methods = configured_names("ContextMethods")
            aliases = ast.each_node(:lvasgn).select { |assignment| context?(assignment.expression) }
            ast.each_node(:call) do |read|
              next unless accessors.include?(accessor_name(read.method_name))
              next unless context?(read.receiver) || context_alias?(read.receiver, aliases)

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
            return false unless node&.lvar_type?

            aliases.any? { |assignment| assignment.name == node.children.first && visible_from?(assignment, node) }
          end

          # A local is visible in the method or block that assigns it and in blocks nested inside it.
          def visible_from?(assignment, read)
            scope = assignment.each_ancestor(*LOCAL_SCOPES).first
            scope.nil? || read.each_ancestor(*LOCAL_SCOPES).include?(scope)
          end

          def configured_names(key)
            Array(cop_config[key]).to_set(&:to_sym)
          end

          def accessor_name(name)
            name.to_s.delete_suffix("!").to_sym
          end
        end
      end
    end
  end
end
