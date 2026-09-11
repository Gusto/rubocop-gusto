# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::IdInputArgumentDescription, :config do
  describe "ID input argument descriptions" do
    context "with correct descriptions" do
      it "accepts correct single argument description in mutation" do
        expect_no_offenses(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to update', required: true
          end
        RUBY
      end

      it "accepts correct single argument description in input object" do
        expect_no_offenses(<<~RUBY)
          class DeleteEmployeeInput < BaseInputObject
            argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to delete', required: true
          end
        RUBY
      end

      it "accepts correct array argument description" do
        expect_no_offenses(<<~RUBY)
          class BulkDeleteMutation < BaseMutation
            argument :employee_ids, [ID], 'The identifiers of each Employee (`Employee.id`) to delete', required: true
          end
        RUBY
      end

      it "accepts correct uuid argument description" do
        expect_no_offenses(<<~RUBY)
          class UpdateCompanyMutation < BaseMutation
            argument :company_uuid, ID, 'The identifier of the Company (`Company.uuid`) to update', required: true
          end
        RUBY
      end

      it "accepts various action verbs" do
        expect_no_offenses(<<~RUBY)
          class PlaylistMutation < BaseMutation
            argument :track_id, ID, 'The identifier of the Track (`Track.id`) to add to the playlist', required: true
          end
        RUBY
      end

      it "accepts additional text after the template" do
        expect_no_offenses(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to update. Will fail if employee is terminated.', required: true
          end
        RUBY
      end

      it 'accepts "to filter by" pattern (matches the template)' do
        expect_no_offenses(<<~RUBY)
          class SaveCalculatedCreditMutation < BaseMutation
            argument :company_id, ID, 'The identifier of the Company (`Company.id`) to filter by', required: true
          end
        RUBY
      end

      it "accepts multiple type references joined by or" do
        expect_no_offenses(<<~RUBY)
          class UpdateDistributionPreferenceMutation < BaseMutation
            argument :id, ID, 'The identifier of the Employee (`Employee.id`) or Contractor (`Contractor.id`) to update the distribution preference for', required: true
          end
        RUBY
      end
    end

    context "with incorrect descriptions" do
      it "registers offense for generic description in mutation" do
        expect_offense(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :employee_id, ID, 'Employee ID', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "registers offense for generic description in input object" do
        expect_offense(<<~RUBY)
          class DeleteEmployeeInput < BaseInputObject
            argument :employee_id, ID, 'The employee ID', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "accepts any valid object name in description" do
        # The cop only validates the pattern format, not that the object name
        # matches the argument name (e.g., argument :company_id can reference Employee)
        expect_no_offenses(<<~RUBY)
          class UpdateMutation < BaseMutation
            argument :company_id, ID, 'The identifier of the Employee (`Employee.id`) to update', required: true
          end
        RUBY
      end
    end

    context "with missing description" do
      it "does not register offense (let other cops handle missing descriptions)" do
        expect_no_offenses(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :employee_id, ID, required: true
          end
        RUBY
      end
    end

    context "when in a query" do
      it "does not check arguments on query fields (handled by IdFieldArgumentDescription)" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, ID, 'Employee ID', required: true
            end
          end
        RUBY
      end

      it "does not check arguments on regular objects (handled by IdFieldArgumentDescription)" do
        expect_no_offenses(<<~RUBY)
          class Employee < BaseObject
            field :manager, Employee, null: true do
              argument :manager_id, ID, 'Manager ID', required: true
            end
          end
        RUBY
      end
    end

    context "when detecting mutations and input objects" do
      it "detects BaseMutation classes" do
        expect_offense(<<~RUBY)
          class MyMutation < BaseMutation
            argument :id, ID, 'Bad description', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "detects BaseInputObject classes" do
        expect_offense(<<~RUBY)
          class MyInput < BaseInputObject
            argument :id, ID, 'Bad description', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "detects Base::Input classes" do
        expect_offense(<<~RUBY)
          class MyInput < Base::Input
            argument :id, ID, 'Bad description', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "detects namespaced mutation classes" do
        expect_offense(<<~RUBY)
          class MyMutation < Gusto::GraphQL::Objects::BaseMutation
            argument :id, ID, 'Bad description', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end
    end

    context "when matching the base class name by suffix rather than substring" do
      it "still detects a PermissionedMutation base" do
        expect_offense(<<~RUBY)
          class MyMutation < Base::PermissionedMutation
            argument :id, ID, 'Bad description', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it 'does not treat a base that merely contains "Mutation" as a substring as a mutation' do
        # `GraphQLMutationTool` ends in "Tool", not a mutation/input suffix. The old
        # substring check misclassified it as a mutation and enforced the template here.
        expect_no_offenses(<<~RUBY)
          class MyTool < Gusto::AI::GraphQLMutationTool
            argument :id, ID, 'Bad description', required: true
          end
        RUBY
      end
    end

    context "with edge cases" do
      it "ignores non-ID type arguments" do
        expect_no_offenses(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :name, String, 'Employee name', required: true
          end
        RUBY
      end
    end

    # Exercises IdDescriptionConcerns through IdInputArgumentDescription#on_send (public API),
    # complementing id_description_concerns_spec.rb (private helpers / branch coverage).
    context "with the public cop API" do
      it "validates GraphQL::Types::ID arguments the same as ID" do
        expect_offense(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :employee_id, GraphQL::Types::ID, 'Employee ID', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "validates [GraphQL::Types::ID] array arguments" do
        expect_offense(<<~RUBY)
          class BulkDeleteMutation < BaseMutation
            argument :employee_ids, [GraphQL::Types::ID], 'Bad', required: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to <action>'.
          end
        RUBY
      end

      it "reads argument description from a block on the argument call" do
        expect_no_offenses(<<~RUBY)
          class UpdateEmployeeMutation < BaseMutation
            argument :employee_id, ID, required: true do
              description 'The identifier of the Employee (`Employee.id`) to update'
            end
          end
        RUBY
      end

      it "does not treat classes with no superclass as mutations (in_mutation_or_input_object?)" do
        expect_no_offenses(<<~RUBY)
          class OrphanMutation
            argument :employee_id, ID, 'Employee ID', required: true
          end
        RUBY
      end
    end
  end
end
