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
      # Detection is file-scoped: a `let` referenced only from another file (through a shared
      # example or an included test harness) cannot be seen, so the cop stays conservative and
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
        # Identifier-shaped tokens inside a string/heredoc literal. A `let` whose name appears only
        # inside string text -- e.g. a binding or column referenced in raw SQL/GraphQL the spec
        # later executes -- counts as referenced, so it is not deleted.
        IDENTIFIER_IN_STRING = /[A-Za-z_]\w*[!?]?/
        MSG = "Remove unreferenced `let(:%{name})` -- its name is never used, so the block never runs."
        RESTRICT_ON_SEND = %i(let).freeze
        SUPPORT_FILES_GLOB = "**/spec/support/**/*.rb"

        # The name symbol of any definition (`let`/`let!`/`subject`) in any block form -- used to
        # count how many times a name is defined, so override / `super` chains (including a
        # `subject` that overrides a `let` of the same name) are never flagged.
        # @!method definition_name(node)
        def_node_matcher :definition_name, <<~PATTERN
          (any_block (send nil? %DEFINITION_METHODS (sym $_) ...) ...)
        PATTERN

        class << self
          # Names defined as `let`/`subject` anywhere under `spec/support/**`. Computed once per
          # process (lazily, after boot) and shared across every file the cop inspects.
          def framework_let_names
            @framework_let_names ||= scan_framework_let_names(support_file_paths)
          end

          # Enumerate `spec/support/**/*.rb`. No git dependency: some environments (e.g. a build
          # step's working directory) are not a git work tree at all, and shelling out to `git`
          # there is unreliable and noisy.
          def support_file_paths
            ::Dir.glob(SUPPORT_FILES_GLOB)
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

        # A lazy `let` is exempt from deletion whenever file-scoped analysis cannot prove its name
        # is dead: its name is a framework-reserved contract (e.g. `cop_config`), the file
        # dispatches through a name we cannot resolve statically, it consumes shared examples, the
        # `let` is lexically inside a shared-example definition, its name is a `spec/support/**`
        # framework contract, it is overridden by another definition of the same name, or it is
        # referenced somewhere in the file.
        def exempt_from_deletion?(name, block)
          FRAMEWORK_RESERVED_NAMES.include?(name) ||
            dynamic_dispatch? ||
            consumes_shared_examples? ||
            within_shared_definition?(block) ||
            self.class.framework_let_names.include?(name) ||
            overridden?(name) ||
            referenced?(name)
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

        def within_shared_definition?(node)
          node.each_ancestor(:any_block).any? { |ancestor| shared_group?(ancestor) }
        end

        def consumes_shared_examples?
          return @consumes_shared_examples unless @consumes_shared_examples.nil?

          @consumes_shared_examples = processed_source.ast.each_node(:call).any? { |send_node| include?(send_node) }
        end

        # True when the file reflectively dispatches through a name we cannot resolve statically --
        # `send`/`public_send`/`method`/etc. called with anything other than a `sym` or plain `str`
        # first argument (most commonly an interpolated string, `send("expected_#{type}")`). In
        # that case any `let` in the file could be the dispatch target, so none are deleted.
        def dynamic_dispatch?
          return @dynamic_dispatch unless @dynamic_dispatch.nil?

          @dynamic_dispatch = processed_source.ast.each_node(:call).any? do |send_node|
            next false unless DYNAMIC_DISPATCH_METHODS.include?(send_node.method_name)

            target = send_node.first_argument
            target && !target.sym_type? && !target.str_type?
          end
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

        def referenced?(name)
          referenced_names.include?(name)
        end

        # A name is "referenced" if it is called as a bare method (`foo`), appears as a symbol
        # literal (`:foo`) other than the let/subject's own name argument, or appears as an
        # identifier-shaped token inside any string/heredoc literal. The symbol and string cases
        # cover indirect invocation -- `send(:foo)` / `send("foo")`, a `:foo`/`"foo"` listed in a
        # data table the spec later dispatches on, or a binding named only inside raw SQL/GraphQL
        # text the spec executes -- which file-scoped analysis cannot otherwise follow. (Tokenizing
        # string bodies, rather than matching the whole string, keeps a `let` referenced only from
        # inside a multi-word heredoc from being deleted.) Interpolated-string *dispatch* is handled
        # separately by `dynamic_dispatch?`, which exempts the whole file.
        def referenced_names
          @referenced_names ||= processed_source.ast.each_node(:sym, :str, :call).each_with_object(Set.new) do |node, names|
            if node.sym_type?
              names << node.value unless definition_name_argument?(node)
            elsif node.str_type?
              # A string with invalid encoding (e.g. a deliberate bad-UTF-8 test fixture) cannot
              # contain an identifier-shaped reference and would raise on `scan`, so skip it.
              node.value.scan(IDENTIFIER_IN_STRING) { |token| names << token.to_sym } if node.value.valid_encoding?
            elsif node.receiver.nil? && node.arguments.empty?
              names << node.method_name
            end
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
