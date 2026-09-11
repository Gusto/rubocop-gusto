# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      module Graphql
        # Flags a field whose resolver cannot reach the node it hangs off: the method body never
        # reads `object` or `@object`, and no helper it calls in the same class does either. The
        # value is then identical for every node, so the field does not belong on this type.
        #
        # @example Bad - the value does not depend on the node
        #   field :eor_coming_soon_countries, [String], null: false
        #   def eor_coming_soon_countries
        #     BusinessValues::BusinessValueService.get_value_for("eor.coming_soon_countries", nil)
        #   end
        #
        # @example Good - the value depends on the node
        #   field :eor_coming_soon_countries, [String], null: false
        #   def eor_coming_soon_countries
        #     object.eor_coming_soon_countries
        #   end
        class ResolverIgnoresObject < Base
          MSG =
            "Field `:%{name}` has a resolver that never reads `object`, so its value is the same " \
            "for every node. Re-home it, or, if it really does depend on the node, resolve the " \
            "indirect dependency."

          FIELD_NAME_NODE = RuboCop::AST::NodePattern.new("(send nil? :field $(sym _) ...)")

          RESOLUTION_ELSEWHERE = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :field ... (hash <(pair (sym {:resolver :hash_key}) _) ...>))
          PATTERN

          # `resolver_method:` redirects the lookup on the type instance; `method:` names a method on
          # the backing object, which this cop does not read.
          RESOLVER_METHOD = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :field ... (hash <(pair (sym :resolver_method) (sym $_)) ...>))
          PATTERN

          EPHEMERAL_BACKING = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :set_backing_type (const ... :EphemeralObject))
          PATTERN

          DELEGATE_TO_OBJECT = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send nil? :delegate ... (hash <(pair (sym :to) (sym :object)) ...>))
          PATTERN

          # A concern that `requires_ancestor` reaches the node through `T.bind(self, ...).object`,
          # since Sorbet cannot see `object` on the module itself. That reads the node exactly as a
          # bare `object` does, so the receiver form has to count too.
          NODE_READ_THROUGH_RECEIVER = RuboCop::AST::NodePattern.new(<<~PATTERN)
            (send {self (send (const _ :T) :bind self ...)} :object)
          PATTERN

          # A nested class gets its own `on_class`, so the walk must not cross into one.
          SCOPE_BOUNDARY = %i(class module sclass).freeze

          # Fields are never declared inside a `def`, so stopping there loses nothing.
          BODY_BOUNDARY = %i(class module sclass def).freeze

          def on_class(node)
            return unless node.body

            fields = []
            definitions = []
            delegated = []
            ephemeral = T.let(false, T::Boolean)

            walk(node.body, BODY_BOUNDARY) do |child|
              case child.type
              when :send
                next unless child.receiver.nil?

                case child.method_name
                when :field
                  name_node = FIELD_NAME_NODE.match(child)
                  next if name_node.nil? || RESOLUTION_ELSEWHERE.match(child)

                  fields << [name_node, RESOLVER_METHOD.match(child) || name_node.value]
                when :set_backing_type
                  ephemeral = true if EPHEMERAL_BACKING.match(child)
                when :delegate
                  delegated.concat(delegated_names(child))
                end
              when :def
                definitions << child
              end
            end
            return if ephemeral || fields.empty?

            accessors = node_accessors | delegated
            resolvers = {}
            direct = []
            callers_of = {}
            definitions.each { |d| scan_resolver(d, accessors, resolvers, direct, callers_of) }

            reaching = propagate(direct, callers_of)
            fields.each do |name_node, resolver_name|
              next unless resolvers.key?(resolver_name)
              next if reaching.key?(resolver_name)

              add_offense(name_node, message: format(MSG, name: name_node.value))
            end
          end
          alias_method :on_module, :on_class

          private

          def delegated_names(node)
            return [] unless DELEGATE_TO_OBJECT.match(node)

            node.arguments.select(&:sym_type?).map(&:value)
          end

          def scan_resolver(def_node, accessors, resolvers, direct, callers_of)
            resolvers[def_node.method_name] = true
            body = def_node.body
            return if body.nil?

            reads_node = T.let(false, T::Boolean)
            calls = []
            walk(body, SCOPE_BOUNDARY) do |node|
              if node.ivar_type?
                reads_node = true if node.name == :@object
              elsif node.send_type?
                if node.receiver.nil?
                  if (node.method?(:object) && node.arguments.empty?) || accessors.include?(node.method_name)
                    reads_node = true
                  else
                    calls << node.method_name
                  end
                elsif NODE_READ_THROUGH_RECEIVER.match(node)
                  reads_node = true
                end
              end
            end

            if reads_node
              direct << def_node.method_name
            else
              calls.each { |callee| (callers_of[callee] ||= []) << def_node.method_name }
            end
          end

          def propagate(direct, callers_of)
            reaching = {}
            queue = direct.dup
            until queue.empty?
              name = queue.pop
              next if reaching.key?(name)

              reaching[name] = true
              callers_of[name]&.each { |caller_name| queue << caller_name unless reaching.key?(caller_name) }
            end
            reaching
          end

          def node_accessors
            Array(cop_config["NodeAccessors"]).map(&:to_sym)
          end

          def walk(node, boundary, &block)
            yield node
            return if boundary.include?(node.type)

            node.each_child_node { |child| walk(child, boundary, &block) }
          end
        end
      end
    end
  end
end
