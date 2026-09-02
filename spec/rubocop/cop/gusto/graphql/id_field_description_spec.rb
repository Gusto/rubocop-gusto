# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::IdFieldDescription, :config do
  describe "ID field descriptions" do
    context "with correct description matching class name" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, 'The Employee identifier', null: false
          end
        RUBY
      end

      it "accepts description as keyword argument" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false, description: 'The Employee identifier'
          end
        RUBY
      end

      it "accepts description in block" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false do
              description 'The Employee identifier'
            end
          end
        RUBY
      end

      it "strips Type suffix from class name (GraphQL-ruby convention)" do
        expect_no_offenses(<<~RUBY)
          class Office365LicenseType < BaseObject
            field :id, ID, 'The Office365License identifier', null: false
          end
        RUBY
      end

      it "accepts additional text after the template" do
        expect_no_offenses(<<~RUBY)
          class LargeScaleIncident < BaseObject
            field :id, ID, 'The LargeScaleIncident identifier. This is a UUID.', null: false
          end
        RUBY
      end

      it "accepts description starting with [REFERENCE ONLY]" do
        expect_no_offenses(<<~RUBY)
          class Album < BaseObject
            field :id, ID, '[REFERENCE ONLY] The Album identifier', null: false
          end
        RUBY
      end
    end

    context "with graphql_name declaration" do
      it "uses graphql_name instead of class name" do
        expect_no_offenses(<<~RUBY)
          class WhoToPay < BaseObject
            graphql_name 'DraftAccountantClientWhoToPay'
            field :id, ID, 'The DraftAccountantClientWhoToPay identifier', null: false
          end
        RUBY
      end

      it "registers offense when description uses class name instead of graphql_name" do
        expect_offense(<<~RUBY)
          class WhoToPay < BaseObject
            graphql_name 'DraftAccountantClientWhoToPay'
            field :id, ID, 'The WhoToPay identifier', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The DraftAccountantClientWhoToPay identifier'
          end
        RUBY
      end

      it "uses graphql_name in nested module" do
        expect_no_offenses(<<~RUBY)
          module SubgraphPartners
            module Schema
              class AccountantLead < BaseObject
                graphql_name 'PartnerAccountantLead'
                field :id, ID, 'The PartnerAccountantLead identifier', null: false
              end
            end
          end
        RUBY
      end
    end

    context "with incorrect description" do
      it "registers offense for generic description" do
        expect_offense(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, 'The unique identifier', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The Employee identifier'
          end
        RUBY
      end

      it "registers offense when description uses wrong class name" do
        expect_offense(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, 'The Company identifier', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The Employee identifier'
          end
        RUBY
      end

      it "registers offense for keyword argument description" do
        expect_offense(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false, description: 'Unique identifier'
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The Employee identifier'
          end
        RUBY
      end

      it "registers offense for block description" do
        expect_offense(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false do
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The Employee identifier'
              description 'The unique identifier'
            end
          end
        RUBY
      end
    end

    context "with uuid field" do
      it "accepts correct uuid description" do
        expect_no_offenses(<<~RUBY)
          class Company < BaseObject
            field :uuid, ID, 'The Company identifier', null: false
          end
        RUBY
      end
    end

    context "with analytics_id field" do
      it "ignores analytics_id fields (legacy, handled separately)" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :analytics_id, ID, 'Any description is fine here', null: false
          end
        RUBY
      end
    end

    context "with GraphQL::Types::ID type" do
      it "detects GraphQL::Types::ID as an ID type" do
        expect_offense(<<~RUBY)
          class Employee < BaseObject
            field :id, GraphQL::Types::ID, 'Wrong description', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The Employee identifier'
          end
        RUBY
      end
    end

    context "with non-ID fields" do
      it "ignores non-ID type fields" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, String, 'Some random description', null: false
          end
        RUBY
      end
    end

    context "with missing description" do
      it "does not register offense (let other cops handle missing descriptions)" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false
          end
        RUBY
      end
    end

    context "when in nested modules" do
      it "correctly identifies class name in deeply nested modules" do
        expect_no_offenses(<<~RUBY)
          module SubgraphPartners
            module Schema
              module Objects::AccountantsGrowth
                class AccountantLead < BaseObject
                  field :id, ID, 'The AccountantLead identifier', null: false
                end
              end
            end
          end
        RUBY
      end
    end

    context "when class name cannot be determined" do
      it "registers offense without suggestion for field outside class" do
        expect_offense(<<~RUBY)
          field :id, ID, 'Wrong description', null: false
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'.
        RUBY
      end
    end

    context "with module-based interfaces" do
      it "accepts correct description in module interface" do
        expect_no_offenses(<<~RUBY)
          module TaskInterface
            include BaseInterface
            field :id, ID, 'The Task identifier', null: false
          end
        RUBY
      end

      it "strips Interface suffix from module name" do
        expect_no_offenses(<<~RUBY)
          module OnboardingAppInterface
            include BaseInterface
            field :id, ID, 'The OnboardingApp identifier', null: false
          end
        RUBY
      end

      it "registers offense for incorrect description in module interface" do
        expect_offense(<<~RUBY)
          module TaskInterface
            include BaseInterface
            field :id, ID, 'The unique identifier', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The Task identifier'
          end
        RUBY
      end

      it "does not register deeply nested module interfaces" do
        expect_no_offenses(<<~RUBY)
          module SubgraphZenpayroll
            module Schema
              module Interfaces
                module ContributionScheme
                  include BaseInterface
                  field :id, ID, 'The ContributionScheme identifier', null: false
                end
              end
            end
          end
        RUBY
      end

      it "uses graphql_name in module interface when present" do
        expect_no_offenses(<<~RUBY)
          module AccountInterface
            include BaseInterface
            graphql_name 'BankingAccount'
            field :id, ID, 'The BankingAccount identifier', null: false
          end
        RUBY
      end

      it "registers offense when module interface uses wrong graphql_name" do
        expect_offense(<<~RUBY)
          module AccountInterface
            include BaseInterface
            graphql_name 'BankingAccount'
            field :id, ID, 'The Account identifier', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The BankingAccount identifier'
          end
        RUBY
      end

      it "prefers class over module when both are ancestors" do
        expect_no_offenses(<<~RUBY)
          module SomeNamespace
            class Employee < BaseObject
              field :id, ID, 'The Employee identifier', null: false
            end
          end
        RUBY
      end
    end

    # Edge cases that also provide branch coverage for the shared concerns module
    context "with edge cases" do
      it "finds graphql_name when it is the only statement in class body" do
        expect_no_offenses(<<~RUBY)
          class SimpleType < BaseObject
            graphql_name 'Simple'
          end
        RUBY
      end

      it "uses class name when body is empty" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
          end
        RUBY
      end

      it "falls back to class name when graphql_name uses non-string argument" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            graphql_name SOME_CONSTANT
            field :id, ID, 'The Employee identifier', null: false
          end
        RUBY
      end

      it "skips non-send nodes when looking for graphql_name" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            SOME_CONSTANT = 'value'
            field :id, ID, 'The Employee identifier', null: false
          end
        RUBY
      end

      it "does not register block with no description method" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false do
              argument :some_arg, String, required: false
            end
          end
        RUBY
      end

      it "does not register block with empty body" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false do
            end
          end
        RUBY
      end

      it "does not register description method with no arguments" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false do
              description
            end
          end
        RUBY
      end

      it "ignores field with insufficient arguments" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id
          end
        RUBY
      end

      it "ignores fields with variable type" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, some_type, 'Some description', null: false
          end
        RUBY
      end

      it "ignores hash keys other than description" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false, resolver: SomeResolver
          end
        RUBY
      end

      it "ignores description with non-string value" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, ID, null: false, description: SOME_CONSTANT
          end
        RUBY
      end

      it "does not register graphql_name with no arguments" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            graphql_name
            field :id, ID, 'The Employee identifier', null: false
          end
        RUBY
      end

      it "does not register field inside another methods block" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            some_method { field :id, ID, null: false }
          end
        RUBY
      end

      it "handles anonymous class with bad description" do
        expect_offense(<<~RUBY)
          klass = Class.new(BaseObject) do
            field :id, ID, 'The identifier', null: false
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'.
          end
        RUBY
      end

      it "does not register nil literal as type" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :id, nil, 'Some description', null: false
          end
        RUBY
      end
    end

    # Exercises IdDescriptionConcerns through IdFieldDescription#on_send (public API),
    # complementing id_description_concerns_spec.rb (private helpers / branch coverage).
    context "with the public cop API" do
      it "reads description from the field block when the field is nested in an outer block" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            outer_scope do
              field :id, ID, null: false do
                description 'The Employee identifier'
              end
            end
          end
        RUBY
      end

      it "uses positional description when the field is nested in an outer block" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            outer_scope do
              field :id, ID, 'The Employee identifier', null: false
            end
          end
        RUBY
      end

      it "uses graphql_name from the class body when resolving expected description" do
        expect_offense(<<~RUBY)
          class WhoToPay < BaseObject
            graphql_name 'DraftAccountantClientWhoToPay'
            outer_scope do
              field :id, ID, 'The WhoToPay identifier', null: false
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID field description should match template: 'The <ObjectName> identifier'. Suggested: 'The DraftAccountantClientWhoToPay identifier'
            end
          end
        RUBY
      end

      it "resolves type name from a module-based GraphQL interface" do
        expect_no_offenses(<<~RUBY)
          module TaskInterface
            field :id, ID, 'The Task identifier', null: false
          end
        RUBY
      end
    end
  end
end
