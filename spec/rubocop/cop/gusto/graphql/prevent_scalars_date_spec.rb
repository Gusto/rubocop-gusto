# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::PreventScalarsDate, :config do
  context "without arguments" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class EverythingPublic
          MSG = 'Hello'

          def method; end
        end
      RUBY
    end
  end

  context "when argument does not have Graphql::Scalars::Date" do
    it do
      expect_no_offenses(<<~RUBY)
        class EverythingPublic
          argument :foo, ID, required: false, sensitive: false
        end
      RUBY
    end
  end

  context "when field does not have Graphql::Scalars::Date" do
    it do
      expect_no_offenses(<<~RUBY)
        class EverythingPublic
          field :my_field, ID, null: true
        end
      RUBY
    end
  end

  context "when argument has Graphql::Scalars::Date" do
    it do
      expect_offense(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, Graphql::Scalars::Date, required: false, sensitive: false
                         ^^^^^^^^^^^^^^^^^^^^^^ Instead of using Graphql::Scalars::Date, use GraphQL::Types::ISO8601Date or GraphQL::Types::ISO8601DateTime. Graphql::Scalars::Date is an artifact of when the graphql-ruby library did not provide out of the box support for dates
        end
      RUBY
    end
  end

  context "when argument has ::Graphql::Scalars::Date (with :: prefix)" do
    it do
      expect_offense(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ::Graphql::Scalars::Date, required: false, sensitive: false
                         ^^^^^^^^^^^^^^^^^^^^^^^^ Instead of using Graphql::Scalars::Date, use GraphQL::Types::ISO8601Date or GraphQL::Types::ISO8601DateTime. Graphql::Scalars::Date is an artifact of when the graphql-ruby library did not provide out of the box support for dates
        end
      RUBY
    end
  end

  context "when field has Graphql::Scalars::Date" do
    it do
      expect_offense(<<~RUBY)
        class MyMutation < BaseMutation
          field :my_field, Graphql::Scalars::Date, null: true
                           ^^^^^^^^^^^^^^^^^^^^^^ Instead of using Graphql::Scalars::Date, use GraphQL::Types::ISO8601Date or GraphQL::Types::ISO8601DateTime. Graphql::Scalars::Date is an artifact of when the graphql-ruby library did not provide out of the box support for dates
        end
      RUBY
    end
  end

  context "when field has ::Graphql::Scalars::Date (with :: prefix)" do
    it do
      expect_offense(<<~RUBY)
        class MyMutation < BaseMutation
          field :my_field, ::Graphql::Scalars::Date, null: true
                           ^^^^^^^^^^^^^^^^^^^^^^^^ Instead of using Graphql::Scalars::Date, use GraphQL::Types::ISO8601Date or GraphQL::Types::ISO8601DateTime. Graphql::Scalars::Date is an artifact of when the graphql-ruby library did not provide out of the box support for dates
        end
      RUBY
    end
  end
end
