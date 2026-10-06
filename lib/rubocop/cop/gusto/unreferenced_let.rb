# frozen_string_literal: true

require "rubocop-rspec"

module RuboCop
  module Cop
    module Gusto
      # Flags lazy `let` declarations whose name is never referenced. A lazy `let(:name) { ... }`
      # is only evaluated when `name` is called, so an unreferenced one is dead code -- its block
      # never runs -- and is deleted.
      #
      # Eager `let!` is intentionally out of scope: it runs its block before every example for its
      # side effect even when unreferenced, so it cannot simply be deleted. Only plain `let` is
      # handled here.
      #
      # By default detection is file-scoped: a `let` referenced only from another file (through a
      # shared example or an included test harness) cannot be seen, so the cop stays conservative and
      # prefers false negatives over false positives:
      # - a name defined more than once in the file by `let`/`let!`/`subject` (an override /
      #   `super` chain, including a `subject` that overrides a `let` of the same name) is never
      #   flagged;
      # - a `let` declared lexically inside a `shared_examples` / `shared_examples_for` /
      #   `shared_context` block is skipped (its consumers live in other files);
      # - every `let` in a file that uses `it_behaves_like` / `it_should_behave_like` /
      #   `include_examples` / `include_context` is skipped, because an included shared block may
      #   reference the binding by a name we cannot follow statically;
      # - any `let` whose name is also defined as a `let`/`subject` in a `spec/support/**` helper is
      #   skipped, because it is almost certainly overriding a contract an included harness consumes;
      # - `let(:cop_config)` is skipped: it is a rubocop-rspec contract consumed by the `:config`
      #   shared context, not by a reference in the spec file; and
      # - every `let` in a file that reflectively dispatches through a name we cannot resolve
      #   statically (e.g. `send("expected_#{type}")`) is skipped, since any `let` could be the
      #   target.
      # A name counts as referenced if it is called bare (`foo`), appears as a symbol (`:foo`)
      # anywhere but the let's own name argument, or appears as an identifier-shaped token inside
      # any string/heredoc literal -- covering dynamic dispatch, `:foo` entries in data tables the
      # spec later dispatches on, and bindings named only inside raw SQL/GraphQL text.
      #
      # Because a bare `:foo` symbol anywhere counts as a reference, commonly-named lets
      # (`let(:user)`, `let(:company)`, `let(:id)`) are essentially never flagged -- `create(:user)`,
      # `:name` hash keys, and the like saturate the file. This conservative bias means the cop
      # realistically only deletes distinctively-named dead lets; it is not a complete dead-`let`
      # finder.
      #
      # `PerExampleGroup: true` scopes detection to example groups instead. A `let` is live only where
      # code running in its group could read it: a reference in its own group, an enclosing group or
      # a nested one, never a sibling. A reference is a bare call or a call on the example itself
      # (`self.x`, `->(example) { example.x }`); hash keys and factory, stub and lookup arguments are
      # not. Each definition of an overridden name is judged on its own, and a `let!` reads its own
      # name. Shared groups and helper methods defined under `spec/support/**` (and in the
      # `spec/*_helper.rb` files beside it) are resolved, following the groups and helpers they use
      # in turn, so an include or helper call protects only the names that code could read. Harnesses
      # `config` registers by metadata (`include_context`, `include`, hooks) count where the lineage's
      # metadata, the type inferred from the directory, or metadata derived for the file selects
      # them. A reflective call reads the names its target could hold: a pattern for an
      # interpolated name. Anything the cop cannot resolve still protects every `let` in its lineage.
      # `LocalContextIncludes` names include methods that evaluate a sibling `context.rb` (or
      # `<name>_context.rb`), which is then resolved the same way.
      #
      # `Cascade: true` also flags a `let` read only from unreferenced `let`s (including its own block).
      #
      # @example
      #   # bad (name never referenced -- deleted, the block never runs)
      #   let(:unused) { create(:thing) }
      #
      #   # good
      #   let(:thing) { create(:thing) }
      #   it { expect(thing).to be_present }
      #
      class UnreferencedLet < ::RuboCop::Cop::RSpec::Base
        extend AutoCorrector
        include RangeHelp

        DEFINITION_METHODS = Set[:let, :let!, :subject].freeze
        # `let`s consumed by a test framework rather than by a reference in the spec file. The
        # rubocop-rspec `:config` shared context reads `cop_config`, so it is live even though the
        # spec never names it.
        FRAMEWORK_RESERVED_NAMES = %i(cop_config).freeze
        # Reflective dispatch methods whose target is the first argument. When that argument is not
        # a statically-resolvable name (a `sym` or plain `str`) -- e.g. `send("expected_#{type}")` --
        # the called name cannot be known, so the whole file is left untouched.
        DYNAMIC_DISPATCH_METHODS = %i(send public_send __send__ try try! method public_method respond_to?).freeze
        FRAMEWORK_LET_PATTERN = /\b(?:let!?|subject)\s*\(?\s*:([A-Za-z_]\w*[!?]?)/
        HOOK_METHODS = %i(before after around prepend_before append_before prepend_after append_after).freeze
        HOOK_SCOPES = %i(each example all context suite).freeze
        # Identifier-shaped tokens inside a string/heredoc literal. A `let` whose name appears only
        # inside string text -- e.g. a binding or column referenced in raw SQL/GraphQL the spec
        # later executes -- counts as referenced, so it is not deleted.
        IDENTIFIER_IN_STRING = /[A-Za-z_]\w*[!?]?/
        # Methods whose literal arguments name factories, traits, stubbed methods or hash keys, never a
        # `let`.
        INERT_SYMBOL_METHODS = %i(
          receive have_received create build build_stubbed create_list build_list attributes_for create_pair build_pair
          [] []= fetch dig key? has_key? delete
        ).freeze
        MSG = "Remove unreferenced `let(:%{name})` -- its name is never used, so the block never runs."
        # Includes whose block defines a nested example group; `include_context`/`include_examples`
        # evaluate their block in the including group itself.
        NESTING_INCLUDES = %i(it_behaves_like it_should_behave_like).freeze
        RESOLVABLE_INCLUDES = %i(it_behaves_like it_should_behave_like include_examples include_context).freeze
        RESTRICT_ON_SEND = %i(let).freeze
        SHARED_GROUP_METHODS = %i(shared_examples shared_examples_for shared_context).freeze
        SUPPORT_FILES_GLOB = "**/spec/support/**/*.rb"
        INCLUDED_CONTEXT = ::RuboCop::AST::NodePattern.new("(send _ :include_context ({str sym} $_) ...)")
        INCLUDED_MODULE = ::RuboCop::AST::NodePattern.new("(send _ :include (const _ $_) ...)")
        REGEXP_NEW = ::RuboCop::AST::NodePattern.new("(send (const {nil? cbase} :Regexp) :new (str $_))")
        # Harness condition for configuration that applies to every example group, metadata or not.
        UNCONDITIONAL = [:__unconditional__, nil].freeze
        # The `type` rspec-rails infers from a spec's directory (`infer_spec_type_from_file_location!`).
        INFERRED_TYPES = {
          controller: "controllers", helper: "helpers", job: "jobs", mailer: "mailers", model: "models",
          request: "(?:requests|integration|api)", routing: "routing", view: "views", feature: "features",
          system: "system", mailbox: "mailboxes", channel: "channels", generator: "generator",
        }.transform_values { |dir| %r(spec/#{dir}/) }.freeze

        # The names some code could read: literal names, patterns for names it builds by
        # interpolation (`try("#{prefix}_include")`), and whether it dispatches to names its inputs
        # carry (`hash.each_key { |key| send(key) }`), which hash keys and the like can supply.
        Reads = Struct.new(:names, :patterns, :inputs) do
          def self.empty
            new(Set.new, [], false)
          end

          def include?(name)
            names.include?(name) || patterns.any? { |pattern| pattern.match?(name.to_s) }
          end

          def merge!(other)
            names.merge(other.names)
            patterns.concat(other.patterns)
            self.inputs ||= other.inputs
            self
          end
        end

        # The name symbol of any definition (`let`/`let!`/`subject`) in any block form -- used to
        # count how many times a name is defined, so override / `super` chains (including a
        # `subject` that overrides a `let` of the same name) are never flagged.
        # @!method definition_name(node)
        def_node_matcher :definition_name, <<~PATTERN
          (any_block (send nil? %DEFINITION_METHODS (sym $_) ...) ...)
        PATTERN

        # @!method lazy_let?(node)
        def_node_matcher :lazy_let?, <<~PATTERN
          (any_block (send nil? :let (sym _) ...) ...)
        PATTERN

        # @!method subject_name(node)
        def_node_matcher :subject_name, <<~PATTERN
          (any_block (send nil? {:subject :subject!} (sym $_) ...) ...)
        PATTERN

        # @!method eager_let_name(node)
        def_node_matcher :eager_let_name, <<~PATTERN
          (any_block (send nil? :let! (sym $_) ...) ...)
        PATTERN

        class << self
          # Names defined as `let`/`subject` anywhere under `spec/support/**`. Computed once per
          # process (lazily, after boot) and shared across every file the cop inspects.
          def framework_let_names
            @framework_let_names ||= scan_framework_let_names(support_files)
          end

          # Enumerate `spec/support/**/*.rb`. No git dependency: some environments (e.g. a build
          # step's working directory) are not a git work tree at all, and shelling out to `git`
          # there is unreliable and noisy.
          def support_file_paths
            ::Dir.glob(SUPPORT_FILES_GLOB)
          end

          def support_files
            @support_files ||= support_file_paths
          end

          # The support files plus the `spec/*_helper.rb` files beside each `spec/support` directory,
          # which define helpers the same way.
          def indexed_files
            helpers = support_files.filter_map { |path| path[%r{\A(?:.*/)?spec/(?=support/)}] }.uniq.flat_map do |spec_dir|
              ::Dir.glob(::File.join(spec_dir, "*_helper.rb"))
            end
            support_files + helpers
          end

          def scan_framework_let_names(paths)
            paths.each_with_object(Set.new) do |path, names|
              extract_let_names(read_source(path), names)
            end
          end

          def extract_let_names(source, names)
            source.scan(FRAMEWORK_LET_PATTERN) { |(captured)| names << captured.to_sym }
            names
          end

          def read_source(path)
            return "" unless ::File.file?(path)

            ::File.read(path, encoding: "UTF-8")
          end

          # Every name the code behind a shared group (`kind` `:groups`), a helper method (`:defs`) or a
          # module (`:modules`) defined under `spec/support/**` could read, or `nil` when that cannot be
          # bounded. That code is followed through the groups it includes and the helpers it calls.
          # Unbounded when a group is not defined there, or the code dispatches through a name it
          # computes, or includes a group by a name we cannot resolve.
          def support_reads(kind, name, processed_source)
            @support_reads ||= {}
            key = [kind, name]
            return @support_reads[key] if @support_reads.key?(key)

            index = support_index(processed_source)
            @support_reads[key] = reads_from(index[kind][name], index)
          end

          def support_helper?(name, processed_source)
            support_index(processed_source)[:defs].key?(name)
          end

          # Everything the harnesses whose conditions `provided` metadata meets could read: shared
          # groups, modules and `config` hooks registered for that metadata. `provided` holds
          # `[key, value]` pairs, a `nil` value standing for one we cannot know.
          def harness_reads(provided, processed_source)
            index = support_index(processed_source)
            provided = provided.to_set | [UNCONDITIONAL, [:file_path, nil]]
            provided |= index[:derived].filter_map { |pair, filter| pair if derived_applies?(filter, provided, processed_source.file_path.to_s) }
            active = index[:harnesses].keys.select { |condition| condition_met?(condition, provided) }.to_set
            @harness_reads ||= {}
            return @harness_reads[active] if @harness_reads.key?(active)

            @harness_reads[active] = active.flat_map { |condition| index[:harnesses][condition] }.uniq.reduce(Reads.empty) do |reads, target|
              found = harness_target_reads(target, index, processed_source)
              break unless found

              reads.merge!(found)
            end
          end

          # Whether a `define_derived_metadata` filter matches this file: a literal `file_path:` regexp is
          # tested, a metadata filter checked against `provided`; anything else is assumed to match.
          def derived_applies?(filter, provided, path)
            kind, value = filter
            case kind
            when :path then value.match?(path)
            when :metadata then value.all? { |condition| condition_met?(condition, provided) }
            else true
            end
          end

          # A condition with no value asks only for its key; a provided value we cannot know meets any.
          def condition_met?(condition, provided)
            key, value = condition
            provided.any? { |provided_key, provided_value| provided_key == key && (value.nil? || provided_value.nil? || provided_value == value) }
          end

          # A module no support file defines comes from a gem, which cannot read spec `let`s.
          def harness_target_reads(target, index, processed_source)
            kind, name = target
            case kind
            when :chunk then reads_from([name], index)
            when :modules then index[:modules].key?(name) ? support_reads(:modules, name, processed_source) : Reads.empty
            else support_reads(kind, name, processed_source)
            end
          end

          def local_context_reads(path, processed_source)
            @local_context_reads ||= {}
            return @local_context_reads[path] if @local_context_reads.key?(path)

            ast = parse(read_source(path), path, processed_source) if ::File.file?(path)
            @local_context_reads[path] = (reads_from([scan(ast)], support_index(processed_source)) if ast)
          end

          def reads_from(chunks, index)
            return unless chunks

            pending = chunks.dup
            seen = Set.new.compare_by_identity
            reads = Reads.empty
            while (chunk = pending.shift)
              next unless seen.add?(chunk)
              return if chunk[:opaque] || chunk[:includes].any? { |included| !index[:groups].key?(included) }

              reads.names.merge(chunk[:names])
              reads.patterns.concat(chunk[:patterns])
              reads.inputs ||= chunk[:inputs]
              chunk[:includes].each { |included| pending.concat(index[:groups][included]) }
              chunk[:calls].each { |call| pending.concat(index[:defs].fetch(call, [])) }
            end
            reads
          end

          def support_index(processed_source)
            @support_index ||= indexed_files.each_with_object(empty_index) do |path, index|
              ast = parse(read_source(path), path, processed_source)
              index_definitions(ast, index) if ast
            end
          end

          def empty_index
            { groups: {}, defs: {}, modules: {}, harnesses: Hash.new { |hash, key| hash[key] = [] }, derived: Set.new }
          end

          def parse(source, path, processed_source)
            ::RuboCop::ProcessedSource.new(source, processed_source.ruby_version, path, parser_engine: processed_source.parser_engine).ast
          end

          # Indexes each shared group, helper method and module by name, scanned on its own, and each
          # harness `config` registers by the metadata keys that pull it in.
          def index_definitions(ast, index)
            ast.each_node(:any_block, :def, :module, :send) do |node|
              case node.type
              when :def
                (index[:defs][node.method_name] ||= []) << scan(node) if helper_method?(node)
              when :module
                (index[:modules][node.identifier.short_name] ||= []).concat(inclusion_hooks(node))
              when :send
                index_registration(node, index)
              else
                index_block(node, index)
              end
            end
          end

          def index_block(block, index)
            send_node = block.send_node
            name = literal_name(send_node.first_argument)
            if name && SHARED_GROUP_METHODS.include?(send_node.method_name)
              (index[:groups][name] ||= []) << scan(block)
              metadata_conditions(send_node.arguments.drop(1)).each { |condition| index[:harnesses][condition] << [:groups, name] } if send_node.arguments.size > 1
            elsif config_call?(send_node) && HOOK_METHODS.include?(send_node.method_name)
              conditions = metadata_conditions(send_node.arguments.reject { |arg| arg.sym_type? && HOOK_SCOPES.include?(arg.value) })
              conditions.each { |condition| index[:harnesses][condition] << [:chunk, scan(block)] }
            elsif config_call?(send_node) && send_node.method?(:define_derived_metadata)
              index_derived(block, index)
            end
          end

          # The metadata a `define_derived_metadata` block assigns (`metadata[:key] = value`), which can
          # be present without the spec writing it.
          def index_derived(block, index)
            filter = derived_filter(block.send_node.arguments)
            block.each_node(:send) do |node|
              index[:derived] << [[node.first_argument.value, literal_value(node.last_argument)], filter] if node.method?(:[]=) && node.first_argument.sym_type?
            end
          end

          def derived_filter(args)
            return [:always] if args.empty?

            path = args.first.pairs.find { |pair| pair.key.sym_type? && pair.key.value == :file_path } if args.one? && args.first.hash_type?
            return [:path, literal_regexp(path.value)] if path && literal_regexp(path.value)
            return [:metadata, metadata_conditions(args)] unless path

            [:unknown]
          end

          def literal_regexp(node)
            return node.to_regexp if node.regexp_type? && node.children.all? { |part| part.type?(:str, :regopt) }

            (source = REGEXP_NEW.match(node)) && ::Regexp.new(source)
          end

          def index_registration(node, index)
            return unless config_call?(node)

            target = registration_target(node)
            metadata_conditions(node.arguments.drop(1)).each { |condition| index[:harnesses][condition] << target } if target
          end

          def registration_target(node)
            if (name = INCLUDED_CONTEXT.match(node)) then [:groups, name.to_s]
            elsif (name = INCLUDED_MODULE.match(node)) then [:modules, name]
            end
          end

          def config_call?(send_node)
            !send_node.receiver.nil? && !send_node.receiver.self_type? && !send_node.receiver.const_type?
          end

          # `[key, value]` metadata pairs written as arguments: `:key` asks for the key, `key: value` for
          # the value (`nil` when it is not a literal).
          def metadata_conditions(args)
            conditions = args.flat_map do |arg|
              if arg.sym_type? then [[arg.value, nil]]
              elsif arg.hash_type? then arg.pairs.select { |pair| pair.key.sym_type? }.map { |pair| [pair.key.value, literal_value(pair.value)] }
              else []
              end
            end
            conditions.empty? ? [UNCONDITIONAL] : conditions
          end

          def literal_value(node)
            return node.true_type? if node.boolean_type?

            node.value if node.type?(:sym, :str)
          end

          # What including a module runs on its own: its `included`/`extended` hooks. Its other methods
          # only read what they read when called, and calls are followed as helpers.
          def inclusion_hooks(module_node)
            module_node.each_node(:any_block, :defs).select { |node| node.method?(:included) || node.method?(:extended) }.map { |hook| scan(hook) }
          end

          # What code under `root` reads: its symbols (except factory/stub ones and hash keys), bare
          # calls and string tokens; the helpers it calls and groups it includes, to follow; and the
          # patterns of names it builds for dynamic dispatch, or `opaque` when it builds them some
          # other way.
          def scan(root)
            chunk = { calls: Set.new, names: Set.new, includes: [], patterns: [], opaque: false, inputs: false }
            inert = Set.new
            root.each_node do |node|
              case node.type
              when :sym then (inert_symbol?(node) ? inert : chunk[:names]) << node.value
              when :str then (inert_symbol?(node) ? inert : chunk[:names]).merge(string_tokens(node))
              when :send, :csend then scan_call(node, chunk)
              end
            end
            chunk[:names].merge(inert) if chunk[:inputs]
            chunk
          end

          def scan_call(node, chunk)
            if node.receiver.nil?
              chunk[:calls] << node.method_name
              chunk[:names] << node.method_name if node.arguments.empty?
              scan_include(node, chunk) if include_method?(node.method_name)
            end
            case (read = dispatch_read(node))
            when Regexp then chunk[:patterns] << read
            when :inputs then chunk[:inputs] = true
            when :unbounded then chunk[:opaque] = true
            end
          end

          def scan_include(node, chunk)
            name = literal_name(node.first_argument)
            name && RESOLVABLE_INCLUDES.include?(node.method_name) ? chunk[:includes] << name : chunk[:opaque] = true
          end

          # A method a spec could call bare: defined at the top level, in a block, or in a module that
          # can be mixed into example groups -- not an instance method of some class.
          def helper_method?(def_node)
            !def_node.each_ancestor(:class, :sclass, :module).first&.type?(:class, :sclass)
          end

          def include_method?(method_name)
            ::RuboCop::RSpec::Language.config.fetch("Includes", {}).values.flatten.include?(method_name.to_s)
          end

          def literal_name(node)
            node.value.to_s if node&.type?(:str, :sym)
          end

          # A symbol or string that cannot name a `let`: a hash key, or a factory, trait, stubbed method
          # or hash lookup name.
          def inert_symbol?(node)
            parent = node.parent
            return parent.key.equal?(node) if parent.pair_type?

            parent.send_type? && INERT_SYMBOL_METHODS.include?(parent.method_name) && parent.arguments.any? { |arg| arg.equal?(node) }
          end

          def dynamic_target?(node)
            return false unless DYNAMIC_DISPATCH_METHODS.include?(node.method_name)

            target = node.first_argument
            !target.nil? && !target.type?(:sym, :str)
          end

          # What a reflective call that can reach a `let` (no receiver, or `self`) reads beyond its
          # literal names: nothing for a literal target; `:inputs` when the target is a parameter, a
          # variable assigned only literals, or a bare call returning one, so any literal could
          # supply the name; a pattern when it interpolates around literal text; `:unbounded`
          # otherwise.
          def dispatch_read(node)
            return unless DYNAMIC_DISPATCH_METHODS.include?(node.method_name) && (node.receiver.nil? || node.receiver.self_type?)

            target = node.first_argument
            return if target.nil? || target.type?(:sym, :str)
            return :inputs if literal_valued?(target)

            target.type?(:dstr, :dsym) ? interpolation_pattern(target) : :unbounded
          end

          def literal_valued?(node)
            case node.type
            when :lvar
              node.each_ancestor.to_a.last.each_node(:lvasgn).none? do |assignment|
                assignment.name == node.children.first && !assignment.expression&.type?(:sym, :str)
              end
            when :send then node.receiver.nil? && node.arguments.empty?
            else false
            end
          end

          def interpolation_pattern(node)
            parts = node.children.map { |part| part.str_type? ? ::Regexp.escape(part.value) : (literal_alternatives(part) || "\\w*") }
            return :unbounded unless node.children.any?(&:str_type?)

            ::Regexp.new("\\A#{parts.join}[!?]?\\z")
          end

          # `(?:a|b)` for an interpolated block parameter bound by iterating a literal array or hash.
          def literal_alternatives(part)
            variable = part.children.first
            return unless part.children.one? && variable.lvar_type?

            block = variable.each_ancestor(:block).find { |ancestor| ancestor.argument_list.first&.name == variable.children.first }
            values = literal_collection(block.receiver) if block
            "(?:#{values.map { |value| ::Regexp.escape(value) }.join('|')})" if values
          end

          def literal_collection(node)
            return unless node&.type?(:array, :hash)

            elements = node.hash_type? ? node.keys : node.children
            elements.map { |element| element.value.to_s } if elements.all? { |element| element.type?(:sym, :str) }
          end

          # A string with invalid encoding (e.g. a deliberate bad-UTF-8 test fixture) cannot contain
          # an identifier-shaped reference and would raise on `scan`, so it yields none.
          def string_tokens(node)
            node.value.valid_encoding? ? node.value.scan(IDENTIFIER_IN_STRING).map(&:to_sym) : []
          end
        end

        def on_send(node)
          return unless node.receiver.nil?

          name_argument = node.first_argument
          return unless name_argument&.sym_type?

          block = node.block_node
          return unless block

          name = name_argument.value
          return if exempt_from_deletion?(name, block)

          add_offense(node.loc.selector, message: format(MSG, name:)) do |corrector|
            corrector.remove(removal_range(block))
          end
        end

        private

        def exempt_from_deletion?(name, block)
          FRAMEWORK_RESERVED_NAMES.include?(name) ||
            (!per_example_group? && dynamic_dispatch?) ||
            within_shared_definition?(block) ||
            !dead_lets.include?(block)
        end

        def per_example_group?
          cop_config.fetch("PerExampleGroup", false)
        end

        def cascade?
          cop_config.fetch("Cascade", false)
        end

        def local_context_includes
          @local_context_includes ||= Array(cop_config["LocalContextIncludes"]).to_set(&:to_sym)
        end

        def dead_lets
          @dead_lets ||= begin
            dead = find_dead(identity_set)
            while cascade? && (next_dead = find_dead(dead)).size > dead.size
              dead = next_dead
            end
            dead
          end
        end

        def find_dead(dead)
          identity_set.merge(lazy_lets.reject { |let| live?(let, dead) })
        end

        def identity_set
          Set.new.compare_by_identity
        end

        def live?(let, dead)
          name = let.send_node.first_argument.value
          scope = scope_of(let)
          exposed_to_reader?(name, scope) ||
            exposed_to_harness?(name, scope) ||
            redefined?(name) ||
            referenced_in_lineage?(name, let, scope, dead)
        end

        def exposed_to_reader?(name, scope)
          reader_sites.any? do |site_scope, reads|
            lineage?(site_scope, scope) &&
              (reads.nil? || reads.include?(name) || (reads.inputs && inert_references.fetch(name, []).any? { |inert_scope| lineage?(inert_scope, site_scope) }))
          end
        end

        # Hash keys and factory, stub and lookup arguments, by name and scope: not references, but a
        # reader that dispatches to names its inputs carry could be handed one.
        def inert_references
          @inert_references ||= processed_source.ast.each_node(:sym, :str).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |node, refs|
            next unless self.class.inert_symbol?(node)

            (node.sym_type? ? [node.value] : self.class.string_tokens(node)).each { |name| refs[name] << scope_of(node) }
          end
        end

        # By file, a name also defined as a `let`/`subject` under `spec/support/**` likely overrides a
        # contract some harness reads. Per example group, the harnesses that metadata in the lineage
        # pulls in are resolved and only their reads count.
        def exposed_to_harness?(name, scope)
          return self.class.framework_let_names.include?(name) unless per_example_group?

          reads = self.class.harness_reads(provided_metadata(scope), processed_source)
          reads.nil? || reads.include?(name)
        end

        # The metadata examples in the lineage of `scope` carry: written on its groups, plus the
        # `type` rspec-rails infers from the file's directory. A bare `:key` reads as `key: true`.
        def provided_metadata(scope)
          written = metadata_scopes.select { |group| lineage?(group, scope) }.flat_map do |group|
            group.send_node.arguments.drop(1).flat_map do |arg|
              next [[arg.value, true]] if arg.sym_type?

              arg.hash_type? ? arg.pairs.select { |pair| pair.key.sym_type? }.map { |pair| [pair.key.value, self.class.literal_value(pair.value)] } : []
            end
          end
          written + inferred_type
        end

        def inferred_type
          @inferred_type ||= INFERRED_TYPES.filter_map { |type, directory| [:type, type] if processed_source.file_path.to_s.match?(directory) }
        end

        def redefined?(name)
          per_example_group? ? subject_names.include?(name) : overridden?(name)
        end

        def referenced_in_lineage?(name, let, scope, dead)
          references.fetch(name, []).any? do |reference_scope, container|
            next false if cascade? && (container.equal?(let) || dead.include?(container))

            lineage?(reference_scope, scope)
          end
        end

        # Two scopes share a lineage when one encloses the other: a reference in an enclosing group runs
        # in every nested example, and a reference in a nested group resolves outward to the definition.
        # `nil` is file-wide and shares a lineage with everything.
        def lineage?(scope, other)
          scope.nil? || other.nil? || scope.equal?(other) ||
            scope.each_ancestor(:any_block).any? { |ancestor| ancestor.equal?(other) } ||
            other.each_ancestor(:any_block).any? { |ancestor| ancestor.equal?(scope) }
        end

        # The innermost example group (or block passed to an include such as `it_behaves_like`)
        # enclosing the node, or `nil` for file-wide: outside any group, inside a shared-group
        # definition (its body runs wherever it is included), or when scoping per group is off.
        def scope_of(node)
          return unless per_example_group?

          ancestors = node.each_ancestor(:any_block).to_a
          return if ancestors.any? { |ancestor| shared_group?(ancestor) }

          ancestors.find { |ancestor| example_group?(ancestor) || nesting_include?(ancestor) }
        end

        def nesting_include?(block)
          block.receiver.nil? && NESTING_INCLUDES.include?(block.method_name)
        end

        def lazy_lets
          @lazy_lets ||= identity_set.merge(processed_source.ast.each_node(:any_block).select { |node| lazy_let?(node) })
        end

        def subject_names
          @subject_names ||= processed_source.ast.each_node(:any_block).filter_map { |node| subject_name(node) }.to_set
        end

        # Every place code could read a let other than by naming it, as `[scope, Reads]` (`nil` when
        # unbounded): shared-group includes and, per example group, calls to helper methods defined
        # under `spec/support/**` and reflective calls that build the name they dispatch to.
        def reader_sites
          @reader_sites ||= processed_source.ast.each_node(:send).filter_map do |node|
            if include?(node)
              [scope_of(node.block_node || node), included_reads(node)]
            elsif per_example_group?
              group_reader_site(node)
            end
          end
        end

        def group_reader_site(node)
          if node.receiver.nil? && self.class.support_helper?(node.method_name, processed_source)
            [scope_of(node), self.class.support_reads(:defs, node.method_name, processed_source)]
          elsif (read = self.class.dispatch_read(node))
            [scope_of(node), dispatch_reads(read)]
          end
        end

        def dispatch_reads(read)
          case read
          when ::Regexp then Reads.new(Set.new, [read], false)
          when :inputs then Reads.new(Set.new, [], true)
          end
        end

        def included_reads(node)
          return unless per_example_group?
          return local_context_reads(node) if local_context_includes.include?(node.method_name)
          return unless RESOLVABLE_INCLUDES.include?(node.method_name)

          group = self.class.literal_name(node.first_argument)
          return unless group
          # A group defined in this file is read through its body's references, which count file-wide.
          return Reads.empty if local_shared_groups.include?(group)

          self.class.support_reads(:groups, group, processed_source)
        end

        # A local-context include evaluates a sibling `context.rb`, or `<name>_context.rb` when named.
        def local_context_reads(node)
          name = self.class.literal_name(node.first_argument)
          return if node.first_argument && !name

          path = ::File.join(::File.dirname(processed_source.file_path), name ? "#{name}_context.rb" : "context.rb")
          self.class.local_context_reads(path, processed_source)
        end

        def local_shared_groups
          @local_shared_groups ||= processed_source.ast.each_node(:any_block).filter_map do |node|
            self.class.literal_name(node.send_node.first_argument) if shared_group?(node)
          end.to_set
        end

        def metadata_scopes
          @metadata_scopes ||= processed_source.ast.each_node(:any_block).select do |node|
            example_group?(node) && node.send_node.arguments.drop(1).any? { |arg| arg.type?(:sym, :hash) }
          end
        end

        # Every reference to a name, keyed by name, as `[scope, enclosing lazy let]` pairs. A name is
        # referenced where it is called bare (`foo`), appears as a symbol (`:foo`) other than a
        # definition's own name argument, or appears as an identifier-shaped token inside any
        # string/heredoc literal. The symbol and string cases cover indirect invocation --
        # `send(:foo)` / `send("foo")`, a `:foo` listed in a data table the spec later dispatches on,
        # or a binding named only inside raw SQL/GraphQL text -- which static analysis cannot
        # otherwise follow. A `let!` references its own name from its own scope, since its eager
        # hook calls it before every example there.
        def references
          @references ||= processed_source.ast.each_node(:sym, :str, :call, :any_block).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |node, refs|
            reference_names(node).each { |name| refs[name] << [scope_of(node), (enclosing_lazy_let(node) if cascade?)] }
          end
        end

        def reference_names(node)
          case node.type
          when :sym then definition_name_argument?(node) || (per_example_group? && self.class.inert_symbol?(node)) ? [] : [node.value]
          when :str then per_example_group? && self.class.inert_symbol?(node) ? [] : self.class.string_tokens(node)
          when :send, :csend then node.arguments.empty? && example_receiver?(node.receiver) ? [node.method_name] : []
          else Array(eager_let_name(node))
          end
        end

        # A call reaches a `let` when it has no receiver, or, per example group, when its receiver may be
        # the example itself: `self`, or a block parameter (`->(example) { example.payroll }`).
        def example_receiver?(receiver)
          return true if receiver.nil?
          return false unless per_example_group?

          receiver.self_type? || (receiver.lvar_type? && block_parameter?(receiver))
        end

        def block_parameter?(lvar)
          lvar.each_ancestor(:any_block).any? do |block|
            block.respond_to?(:argument_list) && block.argument_list.any? { |argument| argument.name == lvar.children.first }
          end
        end

        def enclosing_lazy_let(node)
          node.each_ancestor(:any_block).find { |ancestor| lazy_lets.include?(ancestor) }
        end

        # Delete the `let` block, plus:
        # - an immediately-preceding `sig { ... }` (so a Sorbet signature is not left dangling),
        # - explanatory comment lines attached directly above it (so they are not orphaned), and
        # - a single trailing blank line where removal would otherwise leave a stray/duplicate
        #   blank -- unless the line above is a `let`/`subject`, where that blank is the required
        #   separator after the now-final let and must stay.
        def removal_range(node)
          lines = processed_source.lines
          start_line = node.source_range.first_line
          end_line = node.source_range.last_line

          sig = preceding_sig(node)
          start_line = sig.source_range.first_line if sig

          start_line -= 1 while start_line > 1 && absorbable_comment?(lines[start_line - 2])

          if end_line < lines.size && blank_line?(lines[end_line]) &&
              !(start_line > 1 && let_or_subject_line?(lines[start_line - 2]))
            end_line += 1
          end

          buffer = processed_source.buffer
          range_by_whole_lines(buffer.line_range(start_line).join(buffer.line_range(end_line)), include_final_newline: true)
        end

        def absorbable_comment?(source_line)
          stripped = source_line.strip
          stripped.start_with?("#") && !stripped.start_with?("# rubocop:")
        end

        def blank_line?(source_line)
          source_line.strip.empty?
        end

        def let_or_subject_line?(source_line)
          source_line.match?(/\A\s*(?:let!?|subject)\b/)
        end

        def preceding_sig(node)
          sibling = node.left_sibling
          return unless sibling.is_a?(::RuboCop::AST::BlockNode)
          return unless sibling.method?(:sig)

          sibling
        end

        # Per example group, a shared group nested in an example group is only visible to this file, so
        # its `let`s are judged file-wide like any other; a top-level one may be included elsewhere.
        def within_shared_definition?(node)
          node.each_ancestor(:any_block).any? do |ancestor|
            shared_group?(ancestor) && !(per_example_group? && ancestor.each_ancestor(:any_block).any? { |outer| example_group?(outer) })
          end
        end

        # True when the file reflectively dispatches through a name we cannot resolve statically --
        # `send`/`public_send`/`method`/etc. called with anything other than a `sym` or plain `str`
        # first argument (most commonly an interpolated string, `send("expected_#{type}")`). In
        # that case any `let` in the file could be the dispatch target, so none are deleted.
        def dynamic_dispatch?
          return @dynamic_dispatch unless @dynamic_dispatch.nil?

          @dynamic_dispatch = processed_source.ast.each_node(:call).any? { |node| self.class.dynamic_target?(node) }
        end

        def overridden?(name)
          definitions_by_name.fetch(name, 0) > 1
        end

        def definitions_by_name
          @definitions_by_name ||= processed_source.ast.each_node(:any_block).each_with_object(Hash.new(0)) do |node, counts|
            name = definition_name(node)
            counts[name] += 1 if name
          end
        end

        def definition_name_argument?(sym_node)
          parent = sym_node.parent
          parent.send_type? && parent.receiver.nil? && DEFINITION_METHODS.include?(parent.method_name)
        end
      end
    end
  end
end
