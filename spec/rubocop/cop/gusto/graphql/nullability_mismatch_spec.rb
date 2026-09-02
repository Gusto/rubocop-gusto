# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::NullabilityMismatch, :config do
  # --- Direction 1: null: false + T.nilable (runtime crash) ---

  it "flags a non-null field whose resolver returns T.nilable" do
    expect_offense(<<~RUBY)
      class CutoffType < BaseObject
        field :cutoff_time, ::GraphQL::Types::ISO8601DateTime, null: false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Field `:cutoff_time` is declared `null: false` but resolver sig returns `T.nilable`. Either mark the field `null: true` or change the sig.

        sig { override.returns(T.nilable(Time)) }
        def cutoff_time
          object.cutoff_time
        end
      end
    RUBY
  end

  it "flags when sig uses abstract.returns(T.nilable(...))" do
    expect_offense(<<~RUBY)
      class DueDateType < BaseObject
        field :due_date, ::GraphQL::Types::ISO8601Date, null: false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Field `:due_date` is declared `null: false` but resolver sig returns `T.nilable`. Either mark the field `null: true` or change the sig.

        sig { abstract.returns(T.nilable(Date)) }
        def due_date
        end
      end
    RUBY
  end

  it "flags when T.nilable is wrapped in T::Promise" do
    expect_offense(<<~RUBY)
      class PayScheduleType < BaseObject
        field :pay_schedule, PayScheduleType, null: false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Field `:pay_schedule` is declared `null: false` but resolver sig returns `T.nilable`. Either mark the field `null: true` or change the sig.

        sig { returns(T::Promise[T.nilable(::PaySchedule)]) }
        def pay_schedule
          loader.load(object.pay_schedule_id)
        end
      end
    RUBY
  end

  # --- No offense cases ---

  it "does not flag when the field's null: declaration and the resolver sig agree" do
    expect_no_offenses(<<~RUBY)
      class CutoffType < BaseObject
        field :cutoff_time, ::GraphQL::Types::ISO8601DateTime, null: true

        sig { override.returns(T.nilable(Time)) }
        def cutoff_time
          object.cutoff_time
        end
      end

      class CheckDateType < BaseObject
        field :check_date, ::GraphQL::Types::ISO8601Date, null: false

        sig { override.returns(Date) }
        def check_date
          object.check_date
        end
      end
    RUBY
  end

  it "does not flag a field with no inline resolver method" do
    expect_no_offenses(<<~RUBY)
      class DelegatingType < BaseObject
        field :check_date, ::GraphQL::Types::ISO8601Date, null: false
        field :name, String, null: true
      end
    RUBY
  end

  it "does not flag (or crash on) a field declared without an explicit null: parameter" do
    expect_no_offenses(<<~RUBY)
      class NameType < BaseObject
        field :name, String

        sig { override.returns(String) }
        def name
          object.name
        end
      end
    RUBY
  end

  it "does not flag when T.nilable appears only in params, not returns" do
    expect_no_offenses(<<~RUBY)
      class LabelType < BaseObject
        field :label, String, null: false

        sig { params(ctx: T.nilable(String)).returns(String) }
        def label(ctx: nil)
          object.label
        end
      end
    RUBY
  end

  # T.untyped return: nullability can't be determined, so a null: false field does not flag.
  it "does not flag a null: false field whose resolver returns T.untyped" do
    expect_no_offenses(<<~RUBY)
      class NonNullDataType < BaseObject
        field :data, String, null: false

        sig { returns(T.untyped) }
        def data
          object.data
        end
      end
    RUBY
  end

  it "does not flag when the preceding sig is void" do
    expect_no_offenses(<<~RUBY)
      class PerformType < BaseObject
        field :perform, String, null: false

        sig { void }
        def perform
          do_something
        end
      end
    RUBY
  end

  it "does not flag when the matching def is inside a nested class body" do
    expect_no_offenses(<<~RUBY)
      class OuterType < BaseObject
        field :label, String, null: false

        class Nested
          def label
            'label'
          end
        end
      end
    RUBY
  end

  it "does not flag when an unrelated def follows the nilable sig" do
    expect_no_offenses(<<~RUBY)
      class CutoffType < BaseObject
        field :cutoff_time, ::GraphQL::Types::ISO8601DateTime, null: false

        sig { override.returns(T.nilable(Time)) }
        def other_method
          object.other_method
        end

        def cutoff_time
          object.cutoff_time
        end
      end
    RUBY
  end

  it "does not flag when the resolver def is the first statement in the class body" do
    expect_no_offenses(<<~RUBY)
      class LabelType < BaseObject
        def label
          object.label
        end

        field :label, String, null: false
      end
    RUBY
  end

  it "does not flag (or crash on) an empty class body" do
    expect_no_offenses(<<~RUBY)
      class EmptyType < BaseObject
      end
    RUBY
  end
end
