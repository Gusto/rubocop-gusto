# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::IdFieldArgumentDescription, :config do
  describe "ID field argument descriptions" do
    context "with correct descriptions" do
      it "accepts correct single argument description" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to filter by', required: true
            end
          end
        RUBY
      end

      it "accepts correct array argument description" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employees, [Employee], null: true do
              argument :employee_ids, [ID], 'The identifiers of each Employee (`Employee.id`) to filter by', required: true
            end
          end
        RUBY
      end

      it "accepts correct uuid argument description" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :company, Company, null: true do
              argument :company_uuid, ID, 'The identifier of the Company (`Company.uuid`) to filter by', required: true
            end
          end
        RUBY
      end

      it 'accepts a multi-entity ("X or Y") reference' do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :worker, Worker, null: true do
              argument :recipient_id, ID, 'The identifier of the Employee (`Employee.id`) or Contractor (`Contractor.id`) to filter by', required: true
            end
          end
        RUBY
      end

      it "accepts a multi-entity array reference" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :workers, [Worker], null: true do
              argument :recipient_ids, [ID], 'The identifiers of each Employee (`Employee.id`) or Contractor (`Contractor.id`) to filter by', required: true
            end
          end
        RUBY
      end

      it "accepts additional text after the template" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, ID, 'The identifier of the Employee (`Employee.id`) to filter by. Returns null if not found.', required: true
            end
          end
        RUBY
      end
    end

    context "with incorrect descriptions" do
      it "registers offense for generic description" do
        expect_offense(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, ID, 'Employee ID', required: true
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by'.
            end
          end
        RUBY
      end

      it "accepts any valid object name in description" do
        # The cop only validates the pattern format, not that the object name
        # matches the argument name (e.g., argument :company_id can reference Employee)
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :company_id, ID, 'The identifier of the Employee (`Employee.id`) to filter by', required: true
            end
          end
        RUBY
      end
    end

    context "with missing description" do
      it "does not register offense (let other cops handle missing descriptions)" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, ID, required: true
            end
          end
        RUBY
      end
    end

    context "when in a mutation" do
      it "does not check arguments in mutations (handled by IdInputArgumentDescription)" do
        expect_no_offenses(<<~RUBY)
          class TerminateEmployeeMutation < BaseMutation
            argument :employee_id, ID, 'Employee ID', required: true
          end
        RUBY
      end

      it "does not check arguments in input objects (handled by IdInputArgumentDescription)" do
        expect_no_offenses(<<~RUBY)
          class TerminateEmployeeInput < BaseInputObject
            argument :employee_id, ID, 'Employee ID', required: true
          end
        RUBY
      end

      it "does not check arguments in Base::Input classes (handled by IdInputArgumentDescription)" do
        expect_no_offenses(<<~RUBY)
          class SaveDeprovisionAppsInput < Base::Input
            argument :termination_id, ID, 'The identifier of the Termination', required: true
          end
        RUBY
      end
    end

    context "with edge cases" do
      it "ignores non-ID type arguments" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :name, String, 'Employee name', required: true
            end
          end
        RUBY
      end
    end

    # Exercises IdDescriptionConcerns through IdFieldArgumentDescription#on_send (public API),
    # complementing id_description_concerns_spec.rb (private helpers / branch coverage).
    context "with the public cop API" do
      it "validates GraphQL::Types::ID arguments the same as ID" do
        expect_offense(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, GraphQL::Types::ID, 'Employee ID', required: true
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by'.
            end
          end
        RUBY
      end

      it "validates [GraphQL::Types::ID] array arguments" do
        expect_offense(<<~RUBY)
          class Query < BaseObject
            field :employees, [Employee], null: true do
              argument :employee_ids, [GraphQL::Types::ID], 'Bad', required: true
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by'.
            end
          end
        RUBY
      end

      it "reads argument description from a block on the argument call" do
        expect_no_offenses(<<~RUBY)
          class Query < BaseObject
            field :employee, Employee, null: true do
              argument :employee_id, ID, required: true do
                description 'The identifier of the Employee (`Employee.id`) to filter by'
              end
            end
          end
        RUBY
      end

      it "still validates arguments when the enclosing class has no explicit superclass" do
        expect_offense(<<~RUBY)
          class OrphanQuery
            field :employee, Employee, null: true do
              argument :employee_id, ID, 'Employee ID', required: true
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ID argument description should match template: 'The identifier of the <ObjectName> (`<ObjectName.fieldName>`) to filter by'.
            end
          end
        RUBY
      end
    end
  end
end
