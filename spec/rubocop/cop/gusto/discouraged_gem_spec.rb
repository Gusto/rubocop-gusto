# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::DiscouragedGem, :config do
  let(:cop_config) do
    {
      "Gems" => ["some_gem"],
      "MessagePerGem" => {},
    }
  end

  context "when using an allowed gem" do
    let(:source) do
      <<~RUBY
        gem 'rspec'
        gem 'rubocop'
        gem 'rails'
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when using add_dependency with an allowed gem" do
    let(:source) do
      <<~RUBY
        spec.add_dependency 'rspec'
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when using add_development_dependency with an allowed gem" do
    let(:source) do
      <<~RUBY
        spec.add_development_dependency 'rubocop'
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when gem method is called with a variable" do
    let(:source) do
      <<~RUBY
        gem gem_name
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when gem method is called with an expression" do
    let(:source) do
      <<~RUBY
        gem some_method_call
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when gem method is called without arguments" do
    let(:source) do
      <<~RUBY
        gem
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when add_dependency is called without arguments" do
    let(:source) do
      <<~RUBY
        spec.add_dependency
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when add_dependency is called with a variable" do
    let(:source) do
      <<~RUBY
        spec.add_dependency gem_name
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when add_development_dependency is called with a variable" do
    let(:source) do
      <<~RUBY
        spec.add_development_dependency gem_name
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context "when using a discouraged gem without custom message" do
    let(:cop_config) do
      {
        "Gems" => ["some_other_gem"],
        "MessagePerGem" => {},
      }
    end

    let(:source) do
      <<~RUBY
        gem 'some_other_gem'
        ^^^^^^^^^^^^^^^^^^^^ Avoid using the 'some_other_gem' gem. Prefer built-in or agreed-upon alternatives in this codebase.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when MessagePerGem is not configured" do
    let(:cop_config) do
      {
        "Gems" => ["another_gem"],
      }
    end

    let(:source) do
      <<~RUBY
        gem 'another_gem'
        ^^^^^^^^^^^^^^^^^ Avoid using the 'another_gem' gem. Prefer built-in or agreed-upon alternatives in this codebase.
      RUBY
    end

    it { expect_offense(source) }
  end
end
