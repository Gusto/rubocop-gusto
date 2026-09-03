# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::PaginateArrays, :config do
  context "without array field" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class GqlObject
          field :my_field, String, null: true do
            argument :my_argument, Int, description: 'arg', required: true
          end
        end
      RUBY
    end
  end

  context "without arguments" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class GqlObject
          field do
            argument :my_argument, Int, description: 'arg', required: true
          end
        end
      RUBY
    end
  end

  context "with empty array" do
    it "marks an offense" do
      expect_offense(<<~RUBY)
        class GqlObject
          field :my_field, [] do
                           ^^ Field returns an unbounded array of ``. Paginate it, or declare it a deliberately bounded list.
            argument :my_argument, Int, description: 'arg', required: true
          end
        end
      RUBY
    end
  end

  context "with array fields" do
    it "marks an offense" do
      expect_offense(<<~RUBY)
        class GqlObject
          field :my_field, [Hiring::Candidate], null: true
                           ^^^^^^^^^^^^^^^^^^^ Field returns an unbounded array of `Hiring::Candidate`. Paginate it, or declare it a deliberately bounded list.
        end
      RUBY
    end
  end

  context "with a non_paginated_list" do
    it "does not mark offenses" do
      expect_no_offenses(<<~RUBY)
        class GqlObject
          field :my_field, non_paginated_list(Onboarding::State), null: true
        end
      RUBY
    end
  end
end
