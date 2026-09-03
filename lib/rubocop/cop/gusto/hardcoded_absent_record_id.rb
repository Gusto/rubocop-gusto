# frozen_string_literal: true

require "rubocop-rspec"

module RuboCop
  module Cop
    module Gusto
      # Flags a hardcoded positive id standing in for a record an example expects to be absent.
      #
      # Auto-increment climbs across every example on a test node and is not reclaimed by
      # transactional rollback, so the counter eventually reaches the literal. From then on a
      # real row occupies it, the lookup succeeds, and the example stops testing absence --
      # passing locally, where the counter is low, and failing in CI. A negative id cannot
      # collide, because auto-increment never emits one.
      #
      # An id counts as standing in for an absent record when its own example group either
      # asserts absence (`ActiveRecord::RecordNotFound`, a `:not_found` response) or says so in
      # its description. Both are read from the group the `let` is written in, not the whole
      # file, so a shared id in an outer group is not attributed to a nested example that never
      # uses it.
      #
      # In a list, a literal sitting beside a real `record.id` also qualifies on its own: you
      # would write another `record.id` if you wanted one that exists. That matters because
      # those groups are usually named for the plural ("with multiple bank account IDs") rather
      # than for the gap.
      #
      # Five shapes are deliberately not offenses, because in none of them can the counter reach
      # the literal, or a single replacement would change what the example asserts:
      #
      # - a group that builds a record carrying that id -- the row is meant to exist, so the
      #   absence the group describes is about something else, a cache or a header;
      # - an `ActiveRecord::RecordNotFound` raised by reloading a row the example just deleted,
      #   which is a statement about that object rather than about the literal;
      # - a literal above `MaxId`, which is a deliberate never-collides sentinel;
      # - a group pinning two ids, which are usually pinned to differ from each other, and one
      #   shared replacement collapses that and inverts the example; and
      # - an example group under VCR, whose cassette matches on the id in the request URI.
      #
      # @safety
      #   Autocorrection is unsafe. `-1` is right for a primary key, but it also changes the
      #   value the example feeds to everything else, so an id matched against a stubbed request
      #   URI or an asserted error message needs those updated to match. `-1` is not free
      #   everywhere either: a codebase may reserve it as a sentinel of its own, and an unsigned
      #   column or protobuf field rejects it outright. Where a negative will not do, a sentinel
      #   above `MaxId` is the sanctioned alternative.
      #
      # @example
      #   # bad
      #   context 'when the company does not exist' do
      #     let(:company_id) { 123 }
      #
      #     it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      #   end
      #
      #   # bad - the literal is there precisely because no record has it
      #   let(:bank_account_ids) { [bank_account.id, other_account.id, 999_999] }
      #
      #   # good - auto-increment never emits a negative id
      #   context 'when the company does not exist' do
      #     let(:company_id) { -1 }
      #
      #     it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
      #   end
      #
      #   # good - a deleted record's id is a reference, not a magic constant
      #   context 'when the company does not exist' do
      #     let(:company_id) { deleted_company.id }
      #   end
      #
      # @example AllowedNames: ['wise_id'] (default: [])
      #   # good - a third-party identifier, not a primary key the counter can reach
      #   context 'when the transfer does not exist' do
      #     let(:wise_id) { 5678 }
      #   end
      #
      # @example MaxId: 1000000 (default)
      #   # good - above MaxId the literal is a deliberate never-collides sentinel
      #   let(:company_id) { 9_999_999_999 }
      class HardcodedAbsentRecordId < ::RuboCop::Cop::RSpec::Base
        extend AutoCorrector

        MSG = "Use a negative id for a record expected to be absent."
        RESTRICT_ON_SEND = %i(let let!).freeze

        # `id` itself, or any `<something>_id`, singular or plural.
        ID_NAME = /\A(ids?|.+_ids?)\z/

        # Each phrase is unambiguous on its own: a bare "missing" or "unknown" reads just as
        # naturally about a header or a flag, so neither is here.
        ABSENT_DESCRIPTION = /
          (does|do|did)\s*n[o']?t\s+exist | \bnot\s+exist |
          \bnot\s+found\b | (cannot|can\s*not|can't|couldn't)\s+be\s+found |
          is\s*n[o']?t\s+found | non-?\s?existent | no\s+such |
          invalid\s+\w*\s*\bid\b | \bid\b\s+is\s+invalid |
          does\s*n[o']?t\s+belong | not\s+belong\s+to | unauthorized\s+access |
          (another|other|different)\s+(account|company|customer|employee|member|org|person|user)
        /xi

        NOT_FOUND = /RecordNotFound/
        NOT_FOUND_STATUS = /\A:?(not_found|404)\z/
        BUILDERS = %i(build build! build_list build_stubbed build_stubbed_list create create! create_list).freeze
        DEFAULT_MAX_ID = 1_000_000

        # @!method let_definition(node)
        def_node_matcher :let_definition, <<~PATTERN
          (any_block (send nil? {:let :let!} (sym $_) ...) _ $_)
        PATTERN

        # @!method vcr_metadata?(node)
        def_node_matcher :vcr_metadata?, <<~PATTERN
          {(sym :vcr) (hash <(pair {(sym :vcr) (str "vcr")} _) ...>)}
        PATTERN

        def on_send(node)
          return unless node.parent&.type?(:any_block)

          name, body = let_definition(node.parent)
          return unless body && id_name?(name)
          return if cassette_controlled?(node)

          if body.array_type?
            check_id_list(node, name, body)
          else
            check_id_literal(node, name, body)
          end
        end

        private

        # A third-party identifier stored in a `*_id` field is not a primary key the
        # auto-increment counter can reach, so a name listed in `AllowedNames` is skipped
        # outright -- a named exception in config beats a file-path exclude or a disable.
        def id_name?(name)
          name.to_s.match?(ID_NAME) && !allowed_names.include?(name.to_s)
        end

        def allowed_names
          @allowed_names ||= Array(cop_config["AllowedNames"]).to_set(&:to_s)
        end

        def check_id_literal(node, name, literal)
          value = collidable_id(literal)
          group = value && enclosing_example_group(node)
          return unless group && absent_context?(group)
          return if built_with?(group, name, value) || paired_ids?(group)

          register(literal)
        end

        # Only a lone literal qualifies. Two would both correct to `-1`, and a duplicated id in
        # a list collapses on lookup, changing the count the example asserts.
        def check_id_list(node, name, array)
          literals = array.children.select { |item| collidable_id(item) }
          return unless literals.one?

          group = enclosing_example_group(node)
          return unless list_qualifies?(array, group)

          literal = literals.first
          return if group && built_with?(group, name, collidable_id(literal))

          register(literal)
        end

        def list_qualifies?(array, group)
          return true if array.children.any? { |item| item.send_type? && item.method?(:id) }

          !group.nil? && absent_context?(group)
        end

        def register(literal)
          add_offense(literal) do |corrector|
            corrector.replace(literal, literal.str_type? ? "'-1'" : "-1")
          end
        end

        # A string id reaches the same column as an integer one, so both count; only the sign
        # and the magnitude matter.
        def collidable_id(node)
          value = case node.type
          when :int then node.value
          when :str then Integer(node.value, exception: false)
          end
          value if value&.positive? && value <= max_id
        end

        def max_id
          cop_config.fetch("MaxId", DEFAULT_MAX_ID)
        end

        def enclosing_example_group(node)
          node.each_ancestor(:any_block).find { |ancestor| example_group?(ancestor) }
        end

        def absent_context?(group)
          inspect_group(group).absent?
        end

        def built_with?(group, name, value)
          inspect_group(group).builds?(name, value)
        end

        def paired_ids?(group)
          inspect_group(group).paired_ids?
        end

        def inspect_group(group)
          GroupInspector.new(group, max_id)
        end

        # A cassette keys its recorded interactions off the request URI, so an id in the path is
        # what tells two same-route requests apart. Rewriting it makes the example miss the
        # recording rather than assert absence, and `record: :none` then fails it outright.
        def cassette_controlled?(node)
          node.each_ancestor(:any_block).any? do |ancestor|
            example_group?(ancestor) && ancestor.send_node.arguments.any? { |arg| vcr_metadata?(arg) }
          end
        end

        # Answers the group-level questions: does this group say the record is absent, does it
        # build the record, and does it pin two ids that are meant to differ?
        class GroupInspector
          include ::RuboCop::RSpec::Language
          extend ::RuboCop::AST::NodePattern::Macros

          # @!method let_definition(node)
          def_node_matcher :let_definition, <<~PATTERN
            (any_block (send nil? {:let :let!} (sym $_) ...) _ $_)
          PATTERN

          def initialize(group, max_id)
            @group = group
            @max_id = max_id
          end

          def absent?
            absent_description? || not_found_assertion?(group.body)
          end

          # A group that builds a record carrying this id means the row is meant to exist, so
          # the absence the group describes is about something else.
          def builds?(name, value)
            group.each_descendant(:send).any? do |send_node|
              BUILDERS.include?(send_node.method_name) &&
                send_node.each_descendant.any? { |arg| references?(arg, name) || same_id_value?(arg, value) }
            end
          end

          # Two ids pinned in one group are usually pinned to differ from each other -- a record
          # and the "other company" it must not match. One shared replacement collapses that.
          def paired_ids?
            own_lets(group.body).count { |_name, body| collidable_id(body) } > 1
          end

          private

          attr_reader :group, :max_id

          # Matched against the source rather than the value so an interpolated description
          # ("when #{model} does not exist") still reads as one.
          def absent_description?
            description = group.send_node.first_argument
            return false unless description&.type?(:str, :dstr, :sym)

            ABSENT_DESCRIPTION.match?(description.source)
          end

          # Scoped to this group: the walk stops at a nested example group, whose assertions
          # belong to whatever that group redefines rather than to this `let`.
          def not_found_assertion?(node)
            return false if node.type?(:any_block) && example_group?(node)
            return true if node.send_type? && not_found_matcher?(node)

            node.each_child_node.any? { |child| not_found_assertion?(child) }
          end

          def not_found_matcher?(node)
            case node.method_name
            when :raise_error, :raise_exception
              node.arguments.any? { |arg| NOT_FOUND.match?(arg.source) } && !deleted_record_assertion?(node)
            when :have_http_status
              NOT_FOUND_STATUS.match?(node.first_argument&.source.to_s)
            when :be_not_found then true
            else false
            end
          end

          # `expect { record.reload }.to raise_error(ActiveRecord::RecordNotFound)` asserts that
          # a row the example already holds was deleted by the code under test. That is about
          # the object, not about the literal -- which is usually what selected it for deletion.
          def deleted_record_assertion?(node)
            subject = node.each_ancestor(:send).first&.receiver
            return false unless subject&.type?(:any_block)

            subject.body&.send_type? && subject.body.method?(:reload)
          end

          def collidable_id(node)
            value = case node.type
            when :int then node.value
            when :str then Integer(node.value, exception: false)
            end
            value if value&.positive? && value <= max_id
          end

          def references?(node, name)
            node.send_type? && node.receiver.nil? && node.method?(name)
          end

          # `create(:evaluation, company_id: 1)` beside `let(:company_id) { 1 }` builds the row
          # this id selects, even though the example inlined the literal rather than the `let`.
          def same_id_value?(node, value)
            node.pair_type? && node.key.type?(:sym, :str) &&
              node.key.value.to_s.match?(ID_NAME) && collidable_id(node.value) == value
          end

          def own_lets(node, found = [])
            return found if node.type?(:any_block) && example_group?(node)

            definition = let_definition(node)
            body = definition&.last
            found << definition if body && !body.array_type?
            node.each_child_node { |child| own_lets(child, found) }
            found
          end
        end
      end
    end
  end
end
