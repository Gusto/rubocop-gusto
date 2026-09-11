# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::PreventContextHashAccess, :config do
  # Shared examples use RuboCop's expect_offense interpolation:
  # - %{code} inserts the value into the source
  # - ^{code} generates carets matching the value's width
  shared_examples "common hash access checks" do |accessor:|
    context "with a disallowed key (symbol)" do
      it "registers an offense" do
        code = "#{accessor}[:some_new_key]"
        expect_offense(<<~RUBY, code:)
          class MyClass
            def perform
              %{code}
              ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
            end
          end
        RUBY
      end
    end

    context "with a disallowed key (string)" do
      it "registers an offense" do
        code = %(#{accessor}["some_new_key"])
        expect_offense(<<~RUBY, code:)
          class MyClass
            def perform
              %{code}
              ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
            end
          end
        RUBY
      end
    end

    context "with an allowed key (symbol)" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyClass
            def perform
              #{accessor}[:current_arguments]
            end
          end
        RUBY
      end
    end

    context "with an allowed key (string)" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyClass
            def perform
              #{accessor}["current_arguments"]
            end
          end
        RUBY
      end
    end

    context "with a dynamic key" do
      it "registers an offense" do
        code = "#{accessor}[key]"
        expect_offense(<<~RUBY, code:)
          class MyClass
            def perform
              %{code}
              ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
            end
          end
        RUBY
      end
    end
  end

  shared_examples "bare call checks" do |accessor:|
    context "with a receiver" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyClass
            def perform
              foo.#{accessor}[:some_new_key]
            end
          end
        RUBY
      end
    end

    context "when called as a method without hash access" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyClass
            def perform
              #{accessor}
            end
          end
        RUBY
      end
    end

    context "when using a typed method" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyClass
            def perform
              #{accessor}.some_method
            end
          end
        RUBY
      end
    end

    context "when at the root level with no parent node" do
      it "does not register an offense" do
        expect_no_offenses(accessor)
      end
    end
  end

  shared_examples "local variable checks" do |accessor:|
    context "with a disallowed symbol key on a block parameter" do
      it "registers an offense" do
        code = "#{accessor}[:some_new_key]"
        expect_offense(<<~RUBY, code:)
          items.each do |#{accessor}|
            %{code}
            ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
          end
        RUBY
      end
    end

    context "with a disallowed string key on a block parameter" do
      it "registers an offense" do
        code = %(#{accessor}["some_new_key"])
        expect_offense(<<~RUBY, code:)
          items.each do |#{accessor}|
            %{code}
            ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
          end
        RUBY
      end
    end

    context "with an allowed key on a block parameter" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          items.each do |#{accessor}|
            #{accessor}[:current_arguments]
          end
        RUBY
      end
    end

    context "with a dynamic key on a block parameter" do
      it "registers an offense" do
        code = "#{accessor}[key]"
        expect_offense(<<~RUBY, code:)
          items.each do |#{accessor}|
            %{code}
            ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
          end
        RUBY
      end
    end

    context "with a disallowed key on a method parameter" do
      it "registers an offense" do
        code = "#{accessor}[:some_new_key]"
        expect_offense(<<~RUBY, code:)
          def perform(#{accessor})
            %{code}
            ^{code} Use typed context methods instead of hash access. Example: `context.user_id` instead of `context[:user_id]`.
          end
        RUBY
      end
    end

    context "when a block parameter uses a typed method" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          items.each do |#{accessor}|
            #{accessor}.some_method
          end
        RUBY
      end
    end
  end

  describe "context (bare call)" do
    include_examples "common hash access checks", accessor: "context"
    include_examples "bare call checks", accessor: "context"
  end

  describe "ctx (bare call)" do
    include_examples "common hash access checks", accessor: "ctx"
    include_examples "bare call checks", accessor: "ctx"
  end

  describe "@context (instance variable)" do
    include_examples "common hash access checks", accessor: "@context"
  end

  describe "@ctx (instance variable)" do
    include_examples "common hash access checks", accessor: "@ctx"
  end

  describe "context (local variable)" do
    include_examples "local variable checks", accessor: "context"
  end

  describe "ctx (local variable)" do
    include_examples "local variable checks", accessor: "ctx"
  end

  describe "unrelated hash access" do
    it "does not register an offense for other hashes" do
      expect_no_offenses(<<~RUBY)
        class MyResolver
          def resolve
            some_hash[:some_new_key]
          end
        end
      RUBY
    end

    it "does not register an offense for unrelated instance variables" do
      expect_no_offenses(<<~RUBY)
        class MyResolver
          def resolve
            @foo[:some_key]
          end
        end
      RUBY
    end
  end

  describe "ALLOWED_KEYS constant" do
    it "includes the allowed keys" do
      expect(RuboCop::Cop::Gusto::Graphql::PreventContextHashAccess::ALLOWED_KEYS).to include(:current_arguments)
    end

    it "is frozen" do
      expect(RuboCop::Cop::Gusto::Graphql::PreventContextHashAccess::ALLOWED_KEYS).to be_frozen
    end
  end
end
