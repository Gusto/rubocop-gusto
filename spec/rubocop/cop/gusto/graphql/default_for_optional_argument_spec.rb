# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::DefaultForOptionalArgument, :config do
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

  context "with an empty class" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class EverythingPublic
        end
      RUBY
    end
  end

  context "with an empty argument method" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class EverythingPublic
          argument
        end
      RUBY
    end
  end

  context "when optional argument is not used as a keyword arg in ruby method" do
    it do
      expect_no_offenses(<<~RUBY)
        class EverythingPublic
          argument :foo, ID, required: false, sensitive: false

          def resolve(**args)
          end
        end
      RUBY
    end
  end

  context "when optional argument does not have a default" do
    it do
      expect_offense(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ID, required: false, sensitive: false

          def resolve(foo:, bar: [])
                      ^^^^ Please define a default value for optional arguments.
          end
        end
      RUBY
    end
  end

  context "with fields" do
    context "when optional argument does not have a default" do
      it do
        expect_offense(<<~RUBY)
          class MyMutation < BaseMutation
            field :my_field, String, null: true do
              argument :foo, ID, required: false, sensitive: false
            end
            field :other, ID, null: true do
              argument :bar, String, required: true, sensitive: true
            end

            def my_field(foo:, bar: [])
                         ^^^^ Please define a default value for optional arguments.
            end

            def other(bar:); end
          end
        RUBY
      end
    end
  end

  context "when optional argument has a default" do
    it do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ID, required: false, sensitive: false

          def resolve(foo: 'employee', bar: [])
          end
        end
      RUBY
    end
  end

  context "when argument is required" do
    it do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ID, required: true, sensitive: false

          def resolve(foo:, bar: [])
          end
        end
      RUBY
    end
  end

  context "when there are no optional arguments defined" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ID, required: true

          def resolve(foo:)
          end
        end
      RUBY
    end
  end

  context "when optional arguments are defined but not used in resolve" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ID, required: false
          argument :bar, String, required: false

          def resolve
          end
        end
      RUBY
    end
  end

  context "with no arguments" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          def resolve
          end
        end
      RUBY
    end
  end

  context "with fields that have empty blocks" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          field :my_field, String, null: true do
          end

          def my_field
          end
        end
      RUBY
    end
  end

  context "with non-field blocks inside the class" do
    it "does not mark offenses for blocks that are not field calls" do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          argument :foo, ID, required: false

          scope :active, -> { where(active: true) }

          def resolve(foo: nil)
          end
        end
      RUBY
    end
  end

  context "with a field argument but no corresponding method defined" do
    it "does not mark offenses when the method is absent" do
      expect_no_offenses(<<~RUBY)
        class MyMutation < BaseMutation
          field :my_field, String, null: true do
            argument :foo, ID, required: false
          end
        end
      RUBY
    end
  end
end
