# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::PreventFieldCanCanAction, :config do
  context "when can_can_action is not defined for the field" do
    it do
      expect_no_offenses(<<~RUBY)
        class RandomObject
          argument :foo, ID, required: false, sensitive: false
        end
      RUBY
    end
  end

  context "when can_can_action is defined for the field" do
    it do
      expect_offense(<<~RUBY)
        class RandomObject
          field :foo, ID, null: false, can_can_action: :bar
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Field can_can_actions will soon be deprecated. Please list out the individual fields in the appropriate ability files.
        end
      RUBY
    end
  end

  context "when can_can_action is nil for field" do
    it do
      expect_offense(<<~RUBY)
        class RandomObject
          field :foo, ID, null: false, can_can_action: nil
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Field can_can_actions will soon be deprecated. Please list out the individual fields in the appropriate ability files.
        end
      RUBY
    end
  end

  context "when can_can_action is in the middle of the field definition" do
    it do
      expect_offense(<<~RUBY)
        class RandomObject
          field :foo, ID, null: false, can_can_action: :bar, method: :baz
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Field can_can_actions will soon be deprecated. Please list out the individual fields in the appropriate ability files.
        end
      RUBY
    end
  end

  context "when field is called but the pattern does not match" do
    it do
      expect_no_offenses(<<~RUBY)
        class RandomObject
          field
        end
      RUBY
    end
  end

  context "when can_can_action is used for the object" do
    it do
      expect_no_offenses(<<~RUBY)
        class RandomObject
          can_can_action :show
        end
      RUBY
    end
  end

  context "when can_can_action is used for the mutation" do
    it do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          builds :foo, can_can_action: :bar
          def resolve()
          end
        end
      RUBY
    end
  end
end
