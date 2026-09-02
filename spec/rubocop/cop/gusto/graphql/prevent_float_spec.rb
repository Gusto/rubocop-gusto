# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::PreventFloat, :config do
  it "registers an offense when using Float in field" do
    expect_offense(<<~RUBY)
      field :amount, Float, null: false
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use Float in GraphQL. Use a fixed-precision scalar instead, so money and decimal values are not subject to floating point loss of precision.
    RUBY
  end

  it "registers an offense when using Float in argument" do
    expect_offense(<<~RUBY)
       argument :amount, Float, required: true do
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use Float in GraphQL. Use a fixed-precision scalar instead, so money and decimal values are not subject to floating point loss of precision.
        description 'Amount in dollars to deposit'
      end
    RUBY
  end

  it "registers an offense when using the qualified GraphQL::Types::Float in field" do
    expect_offense(<<~RUBY)
      field :amount, GraphQL::Types::Float, null: false
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use Float in GraphQL. Use a fixed-precision scalar instead, so money and decimal values are not subject to floating point loss of precision.
    RUBY
  end

  it "registers an offense when using the qualified GraphQL::Types::Float in argument" do
    expect_offense(<<~RUBY)
      argument :amount, GraphQL::Types::Float, required: false
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use Float in GraphQL. Use a fixed-precision scalar instead, so money and decimal values are not subject to floating point loss of precision.
    RUBY
  end

  it "registers an offense when using the cbase-qualified ::GraphQL::Types::Float in field" do
    expect_offense(<<~RUBY)
      field :amount, ::GraphQL::Types::Float, null: false
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use Float in GraphQL. Use a fixed-precision scalar instead, so money and decimal values are not subject to floating point loss of precision.
    RUBY
  end

  it "does not register an offense for an unrelated constant that merely ends in Float" do
    expect_no_offenses(<<~RUBY)
      field :amount, Gusto::GraphQL::Scalars::BigFloat, null: false
    RUBY
  end

  it "does not register an offense when using Gusto::GraphQL::Scalars::USDollars in argument" do
    expect_no_offenses(<<~RUBY)
       argument :amount, Gusto::GraphQL::Scalars::USDollars, required: true do
        description 'Amount in dollars to deposit'
      end
    RUBY
  end

  it "does not register an offense when using Gusto::GraphQL::Scalars::Decimal in field" do
    expect_no_offenses(<<~RUBY)
      field :amount, Gusto::GraphQL::Scalars::Decimal, null: false
    RUBY
  end
end
