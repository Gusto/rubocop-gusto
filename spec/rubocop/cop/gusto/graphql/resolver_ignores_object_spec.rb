# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::ResolverIgnoresObject, :config do
  # --- Flagged: the resolver body cannot reach the node ---

  it "flags a resolver that reads only its arguments" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee(cents:)
          Money.new(cents).format
        end
      end
    RUBY
  end

  it "flags a resolver that reads only the request context" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          context.user_role_integer_id
        end
      end
    RUBY
  end

  it "flags a resolver that reads only a constant" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          BusinessValues.get_value_for("fee.flat")
        end
      end
    RUBY
  end

  it "flags a resolver that only delegates to super" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          super
        end
      end
    RUBY
  end

  it "flags a resolver that delegates to super with arguments" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          super(scale: 2)
        end
      end
    RUBY
  end

  it "flags a resolver that memoizes into an instance variable other than @object" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          @memo || FeeService.default
        end
      end
    RUBY
  end

  it "flags a resolver with an empty body" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
        end
      end
    RUBY
  end

  it "flags a field whose only mention of the node is an authorization gate" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false, authorize_with: [:view_own_resource]
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          FeeService.lookup(status: :active)
        end
      end
    RUBY
  end

  it "flags a `resolver_method:` target that ignores the node, anchored on the declaration" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false, resolver_method: :default_fee
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def default_fee
          FeeService.default
        end
      end
    RUBY
  end

  it "flags a field with `method:` whose field-named resolver ignores the node" do
    expect_offense(<<~RUBY)
      class LadderLifeType < BaseObject
        field :id, ID, null: false, method: :uuid
              ^^^ Field `:id` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def id
          GRAPHQL_CACHE_KEY
        end
      end
    RUBY
  end

  it "flags a resolver whose helper chain never reaches the node, without looping on a cycle" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          first_hop
        end

        def first_hop
          second_hop
        end

        def second_hop
          first_hop
        end
      end
    RUBY
  end

  it "flags each offending field independently" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.
        field :seat_cap, Integer, null: false
              ^^^^^^^^^ Field `:seat_cap` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          FeeService.default
        end

        def seat_cap
          SeatService.cap
        end
      end
    RUBY
  end

  it "flags a field declared with the parenthesised block form" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field(
          :flat_fee,
          ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.
          String,
          null: false
        ) do
          argument :scale, Integer, required: false
        end

        def flat_fee
          FeeService.default
        end
      end
    RUBY
  end

  # --- Not flagged: the resolver can reach the node ---

  it "allows a resolver that reads the node directly" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          object.flat_fee
        end
      end
    RUBY
  end

  it "allows a resolver that reads the node through an instance variable" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          @object.flat_fee
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through a helper in the same class" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          fee_service.lookup
        end

        private

        def fee_service
          FeeService.new(object.id)
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through a two-hop helper chain" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          first_hop
        end

        def first_hop
          second_hop
        end

        def second_hop
          object.flat_fee
        end
      end
    RUBY
  end

  it "allows a class whose body contains a call with an explicit receiver" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        EmptyBacking = T.type_alias { T::Hash[Symbol, T.noreturn] }

        field :flat_fee, String, null: false

        def flat_fee
          object.flat_fee
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through the same helper twice" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          base_fee.positive? ? base_fee : 0
        end

        def base_fee
          object.base_fee
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through two separate helpers" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          base_fee + surcharge
        end

        def base_fee
          object.base_fee
        end

        def surcharge
          object.surcharge
        end
      end
    RUBY
  end

  it "allows a resolver that reads the node through a renaming alias" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          company.flat_fee
        end

        def company
          object
        end
      end
    RUBY
  end

  it "allows a `resolver_method:` target that reads the node" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false, resolver_method: :default_fee

        def default_fee
          object.flat_fee
        end
      end
    RUBY
  end

  it "allows a field with `method:` and no field-named resolver, which resolves off the backing object" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false, method: :default_fee

        def default_fee
          FeeService.default
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through a delegated method" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        delegate :company_name, to: :object

        field :flat_fee, String, null: false

        def flat_fee
          FeeService.for(company_name)
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through a delegated method declared with allow_nil" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        delegate :company_name, :trade_name, to: :object, allow_nil: true

        field :flat_fee, String, null: false

        def flat_fee
          FeeService.for(trade_name)
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through T.bind(self, ...)" do
    expect_no_offenses(<<~RUBY)
      module Objects::Company
        extend ActiveSupport::Concern

        requires_ancestor { ::SubgraphZenpayrollUtility::Base::PermissionedObject }

        included do
          field :flat_fee, String, null: false
        end

        def flat_fee
          company = T.bind(self, ::SubgraphZenpayrollUtility::Base::PermissionedObject).object
          FeeService.for(company.uuid)
        end
      end
    RUBY
  end

  it "allows a resolver that reaches the node through a root-scoped ::T.bind(self, ...)" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          FeeService.for(::T.bind(self, PermissionedObject).object)
        end
      end
    RUBY
  end

  it "allows a resolver that reads the node as self.object" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          FeeService.for(self.object)
        end
      end
    RUBY
  end

  it "flags a resolver whose T.bind receiver is not self" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          FeeService.for(T.bind(context, PermissionedObject).object)
        end
      end
    RUBY
  end

  it "flags a resolver that reads object off an unrelated receiver" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          FeeService.for(context.object)
        end
      end
    RUBY
  end

  it "flags a resolver calling a method delegated to something other than the node" do
    expect_offense(<<~RUBY)
      class CompanyType < BaseObject
        delegate :region, to: :context

        field :flat_fee, String, null: false
              ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def flat_fee
          FeeService.for(region)
        end
      end
    RUBY
  end

  # --- Not flagged: nothing local to inspect ---

  it "allows a field with no resolver method, which resolves off the backing object" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false
      end
    RUBY
  end

  it "allows a field whose resolver lives in another file" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false, resolver: Resolvers::FlatFee
      end
    RUBY
  end

  it "allows a field backed by a hash key" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false, hash_key: :flat_fee

        def flat_fee
          FeeService.default
        end
      end
    RUBY
  end

  it "allows a class that declares no fields" do
    expect_no_offenses(<<~RUBY)
      class FeeService
        def flat_fee
          FeeService.default
        end
      end
    RUBY
  end

  it "allows an empty class body" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
      end
    RUBY
  end

  it "allows a method that matches no declared field" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          object.flat_fee
        end

        def unrelated_helper
          FeeService.default
        end
      end
    RUBY
  end

  it "does not match a nested class's resolver against the outer class's fields" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field :flat_fee, String, null: false

        def flat_fee
          object.flat_fee
        end

        class FeeDetail < BaseObject
          def flat_fee
            FeeService.default
          end
        end
      end
    RUBY
  end

  it "does not match a nested class's fields against the outer class's resolvers" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        def flat_fee
          object.flat_fee
        end

        class FeeDetail < BaseObject
          field :flat_fee, String, null: false
        end
      end
    RUBY
  end

  it "allows a bare `field` call with no arguments" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field
      end
    RUBY
  end

  it "allows a field declared with a non-symbol name" do
    expect_no_offenses(<<~RUBY)
      class CompanyType < BaseObject
        field FIELD_NAME, String, null: false
      end
    RUBY
  end

  # --- Interfaces and shared-field modules ---

  it "flags a field on a module-declared interface whose resolver ignores the node" do
    expect_offense(<<~RUBY)
      module CommerceDiscount
        include BaseInterface

        field :description, String, null: false
              ^^^^^^^^^^^^ Field `:description` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def description
          +''
        end
      end
    RUBY
  end

  it "allows a field on a module-declared interface whose resolver reads the node" do
    expect_no_offenses(<<~RUBY)
      module CommerceDiscount
        include BaseInterface

        field :description, String, null: false

        def description
          object.description
        end
      end
    RUBY
  end

  it "does not match a nested class's resolver against an enclosing module's fields" do
    expect_no_offenses(<<~RUBY)
      module Interfaces
        module CommerceDiscount
          field :description, String, null: false

          def description
            object.description
          end
        end
      end
    RUBY
  end

  # --- Types that declare they have no node ---

  it "allows a type backed by EphemeralObject" do
    expect_no_offenses(<<~RUBY)
      class BusinessCalendar < BaseObject
        set_backing_type Gusto::GraphQL::BackingObjects::EphemeralObject

        field :next_business_day, GraphQL::Types::ISO8601Date, null: false

        def next_business_day
          FederalReserveCalendar.next_business_day
        end
      end
    RUBY
  end

  it "allows a type backed by an unqualified EphemeralObject" do
    expect_no_offenses(<<~RUBY)
      class BusinessCalendar < BaseObject
        set_backing_type EphemeralObject

        field :next_business_day, GraphQL::Types::ISO8601Date, null: false

        def next_business_day
          FederalReserveCalendar.next_business_day
        end
      end
    RUBY
  end

  it "flags a type backed by something other than EphemeralObject" do
    expect_offense(<<~RUBY)
      class BusinessCalendar < BaseObject
        set_backing_type Hash

        field :next_business_day, GraphQL::Types::ISO8601Date, null: false
              ^^^^^^^^^^^^^^^^^^ Field `:next_business_day` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

        def next_business_day
          FederalReserveCalendar.next_business_day
        end
      end
    RUBY
  end

  # --- Endless method definitions ---

  # Endless `def` is Ruby 3.0+ syntax, and CopHelper parses at 2.0 by default.
  context "with an endless resolver definition", :ruby30 do
    it "flags an endless resolver that ignores the node" do
      expect_offense(<<~RUBY)
        class CompanyType < BaseObject
          field :flat_fee, String, null: false
                ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

          def flat_fee = BusinessValues.get_value_for("fee.flat")
        end
      RUBY
    end

    it "allows an endless resolver that reads the node" do
      expect_no_offenses(<<~RUBY)
        class CompanyType < BaseObject
          field :flat_fee, String, null: false

          def flat_fee = object.flat_fee
        end
      RUBY
    end
  end

  # --- Accessors that read the node without naming it, declared in config ---

  context "with node accessors configured" do
    let(:cop_config) { { "NodeAccessors" => %w(object_prop load_association) } }

    it "allows a resolver that reads the node through a configured accessor" do
      expect_no_offenses(<<~RUBY)
        class CompanyType < BaseObject
          field :flat_fee, String, null: false

          def flat_fee
            FeeService.lookup(company_uuid: object_prop(:id))
          end
        end
      RUBY
    end

    it "allows a resolver that reaches the node through a configured association loader" do
      expect_no_offenses(<<~RUBY)
        class CompanyType < BaseObject
          field :company_member, MemberType, null: true

          def company_member
            load_association(:company_member).then(&:company_member)
          end
        end
      RUBY
    end

    it "allows a helper chain that ends at a configured accessor" do
      expect_no_offenses(<<~RUBY)
        class CompanyType < BaseObject
          field :flat_fee, String, null: false

          def flat_fee
            company_uuid
          end

          def company_uuid
            object_prop(:id)
          end
        end
      RUBY
    end

    it "still flags a resolver whose only receiverless call is undeclared" do
      expect_offense(<<~RUBY)
        class CompanyType < BaseObject
          field :flat_fee, String, null: false
                ^^^^^^^^^ Field `:flat_fee` has a resolver that never reads `object`, so its value is the same for every node. Re-home it, or, if it really does depend on the node, resolve the indirect dependency.

          def flat_fee
            FeeService.lookup(scope: fallback_scope)
          end
        end
      RUBY
    end
  end
end
