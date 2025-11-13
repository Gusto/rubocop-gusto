# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::DiscouragedGem, :config do
  let(:cop_config) do
    {
      "Gems" => {},
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

  context "when using a discouraged gem with custom message" do
    let(:cop_config) do
      {
        "Gems" => {
          "some_gem" => "Use the approved alternative instead.",
        },
      }
    end

    let(:source) do
      <<~RUBY
        gem 'some_gem'
        ^^^^^^^^^^^^^^ Avoid using the 'some_gem' gem. Use the approved alternative instead.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using a discouraged gem with empty message" do
    let(:cop_config) do
      {
        "Gems" => {
          "some_other_gem" => "",
        },
      }
    end

    let(:source) do
      <<~RUBY
        gem 'some_other_gem'
        ^^^^^^^^^^^^^^^^^^^^ Avoid using the 'some_other_gem' gem.#{' '}
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when Gems config is not set" do
    let(:cop_config) do
      {}
    end

    it "does not register an offense for any gem" do
      source = <<~RUBY
        gem 'anything'
      RUBY

      expect_no_offenses(source)
    end
  end

  context "when method is not in RESTRICT_ON_SEND" do
    let(:cop_config) do
      {
        "Gems" => {
          "some_gem" => "Don't use this!",
        },
      }
    end

    it "does not register an offense even if gem name matches" do
      source = <<~RUBY
        require 'some_gem'
        install 'some_gem'
        load 'some_gem'
      RUBY

      expect_no_offenses(source)
    end
  end
end
