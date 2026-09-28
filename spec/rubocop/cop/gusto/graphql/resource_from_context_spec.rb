# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::ResourceFromContext, :config do
  let(:cop_config) { { "ResourceAccessors" => %w(company_id company_uuid) } }

  def message(source)
    "Take the target from an argument or `object`, not `#{source}`. To default an omitted argument " \
      "from context, fill it in the argument's `prepare:` and give it `default_value: nil` so `prepare` runs."
  end

  it "flags a resolver that finds its record from context" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          Company.find_by!(uuid: context.company_uuid)
                                 ^^^^^^^^^^^^^^^^^^^^ #{message('context.company_uuid')}
        end
      end
    RUBY
  end

  it "flags an authorization block that builds its resource from the context parameter" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        authorize_with :edit_company, as: :company do |_args, context|
          ResourceBuilder.from_company_id(context.company_id)
                                          ^^^^^^^^^^^^^^^^^^ #{message('context.company_id')}
        end
      end
    RUBY
  end

  it "flags a read through a ctx block parameter" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        authorize_with :edit_company, as: :company do |_args, ctx|
          ResourceBuilder.from_company_uuid(ctx.company_uuid)
                                            ^^^^^^^^^^^^^^^^ #{message('ctx.company_uuid')}
        end
      end
    RUBY
  end

  it "flags a read through an input object's context" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        authorize_with :edit_company, as: :company do |args|
          ResourceBuilder.from_company_id(args[:input].context.company_id)
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('args[:input].context.company_id')}
        end
      end
    RUBY
  end

  it "flags a read through the context instance variable" do
    expect_offense(<<~RUBY)
      class CompanyResolver < BaseResolver
        def resolve
          Company.find_by!(uuid: @context.company_uuid)
                                 ^^^^^^^^^^^^^^^^^^^^^ #{message('@context.company_uuid')}
        end
      end
    RUBY
  end

  it "flags a safe-navigation read" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          Company.find(context&.company_id)
                       ^^^^^^^^^^^^^^^^^^^ #{message('context&.company_id')}
        end
      end
    RUBY
  end

  it "flags a read through a Sorbet cast of context" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          Company.find(T.cast(context, GraphqlContext).company_id)
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('T.cast(context, GraphqlContext).company_id')}
        end
      end
    RUBY
  end

  it "flags a read through a local that holds a cast of context" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          this_context = T.cast(context, GraphqlContext)
          Company.find(this_context.company_id)
                       ^^^^^^^^^^^^^^^^^^^^^^^ #{message('this_context.company_id')}
        end
      end
    RUBY
  end

  it "flags a read through a local that holds context as untyped" do
    expect_offense(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          graphql_context = T.let(context, T.untyped)
          Company.find_by!(uuid: graphql_context.company_uuid)
                                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('graphql_context.company_uuid')}
        end
      end
    RUBY
  end

  it "allows a local that holds something other than context" do
    expect_no_offenses(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          status_context = StatusContext.new(object)
          Company.find_by!(uuid: status_context.company_uuid)
        end
      end
    RUBY
  end

  it "allows a method that is not configured as returning context" do
    expect_no_offenses(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          Company.find(typed_context.company_id)
        end
      end
    RUBY
  end

  context "with context methods configured" do
    let(:cop_config) { { "ResourceAccessors" => %w(company_id), "ContextMethods" => %w(typed_context) } }

    it "flags a read through a base class's context method" do
      expect_offense(<<~RUBY)
        class UpdateCompany < BaseMutation
          def resolve
            Company.find(typed_context.company_id)
                         ^^^^^^^^^^^^^^^^^^^^^^^^ #{message('typed_context.company_id')}
          end
        end
      RUBY
    end
  end

  it "allows an empty file" do
    expect_no_offenses("")
  end

  it "allows a context read that fills an omitted argument in prepare" do
    expect_no_offenses(<<~RUBY)
      class UpdateCompanyInput < BaseInputObject
        argument :company_uuid, ID, required: false, default_value: nil,
                                    prepare: -> (value, ctx) { value.presence || ctx.company_uuid }
      end
    RUBY
  end

  it "allows the accessor on anything but context" do
    expect_no_offenses(<<~RUBY)
      class EmployeeType < BaseObject
        def company(employer:)
          [object.company_uuid, employer.company_uuid, @employer.company_uuid, company_uuid]
        end
      end
    RUBY
  end

  it "allows a context method that does not name a resource" do
    expect_no_offenses(<<~RUBY)
      class UpdateCompany < BaseMutation
        def resolve
          Audit.record!(actor: context.current_user)
        end
      end
    RUBY
  end

  context "with no accessors configured" do
    let(:cop_config) { {} }

    it "allows any context read" do
      expect_no_offenses(<<~RUBY)
        class UpdateCompany < BaseMutation
          def resolve
            Company.find_by!(uuid: context.company_uuid)
          end
        end
      RUBY
    end
  end
end
