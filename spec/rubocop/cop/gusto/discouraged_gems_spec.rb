# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::DiscouragedGem, :config do
  let(:cop_config) do
    {
      "Gems" => ["timecop"],
      "MessagePerGem" => {
        "timecop" => "Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.",
      },
    }
  end

  context "when using gem method with timecop in a Gemfile" do
    let(:source) do
      <<~RUBY
        gem 'timecop'
        ^^^^^^^^^^^^^ Avoid using the 'timecop' gem. Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using gem method with timecop and double quotes" do
    let(:source) do
      <<~RUBY
        gem "timecop"
        ^^^^^^^^^^^^^ Avoid using the 'timecop' gem. Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using gem method with timecop and a version" do
    let(:source) do
      <<~RUBY
        gem 'timecop', '~> 0.9.0'
        ^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using the 'timecop' gem. Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using add_dependency in a gemspec" do
    let(:source) do
      <<~RUBY
        spec.add_dependency 'timecop'
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using the 'timecop' gem. Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using add_development_dependency in a gemspec" do
    let(:source) do
      <<~RUBY
        spec.add_development_dependency 'timecop', '~> 0.9.0'
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using the 'timecop' gem. Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.
      RUBY
    end

    it { expect_offense(source) }
  end

  context "when using a symbol instead of string" do
    let(:source) do
      <<~RUBY
        gem :timecop
        ^^^^^^^^^^^^ Avoid using the 'timecop' gem. Use Rails' time helpers (e.g., freeze_time, travel_to) instead of Timecop.
      RUBY
    end

    it { expect_offense(source) }
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

  context "when using a different discouraged gem without custom message" do
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
end
