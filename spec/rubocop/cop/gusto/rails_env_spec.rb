# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::RailsEnv, :config do
  it "registers an offense for `Rails.env.development? || Rails.env.test?`" do
    expect_offense(<<~RUBY)
      Rails.env.development? || Rails.env.test?
                                ^^^^^^^^^^^^^^^ Use Feature Flags or config instead of `Rails.env`.
      ^^^^^^^^^^^^^^^^^^^^^^ Use Feature Flags or config instead of `Rails.env`.
    RUBY
  end

  it "registers an offense for `Rails.env.production?`" do
    expect_offense(<<~RUBY)
      Rails.env.production?
      ^^^^^^^^^^^^^^^^^^^^^ Use Feature Flags or config instead of `Rails.env`.
    RUBY
  end

  it "does not register an offense for `Rails.env`" do
    expect_no_offenses(<<~RUBY)
      Rails.env
    RUBY
  end

  it "does not register an offense for `Rails.env` assignment" do
    expect_no_offenses(<<~RUBY)
      a = Rails.env
    RUBY
  end

  it "does not register an offense for valid Rails.env methods" do
    expect_no_offenses(<<~RUBY)
      Rails.env.capitalize
      Rails.env.empty?
    RUBY
  end

  it "does not register an offense for unrelated config" do
    expect_no_offenses(<<~RUBY)
      Rails.environment
      MyConfig
      MyConfig.env.production?
      almonds.env.production?
    RUBY
  end

  it "does not register an offense for method calls without receiver" do
    expect_no_offenses(<<~RUBY)
      production?
      test?
      development?
    RUBY
  end

  it "does not register an offense for nil receiver" do
    expect_no_offenses(<<~RUBY)
      env.production?
    RUBY
  end

  it "does not register an offense for receiver without const_name" do
    expect_no_offenses(<<~RUBY)
      "string".env.production?
      123.env.production?
    RUBY
  end
end
