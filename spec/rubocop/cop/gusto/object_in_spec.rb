# frozen_string_literal: true

RSpec.describe(RuboCop::Cop::Gusto::ObjectIn, :config) do
  it("registers an offense when using Object#in? with a range") do
    expect_offense(<<~RUBY)
      5.in?(1..10)
      ^^^^^^^^^^^^ Use `Range#cover?` instead of `Object#in?`.
    RUBY
  end

  it("registers an offense when using Object#in? with an exclusive range") do
    expect_offense(<<~RUBY)
      5.in?(1...10)
      ^^^^^^^^^^^^^ Use `Range#cover?` instead of `Object#in?`.
    RUBY
  end

  it("registers an offense when using Object#in? with a range in parentheses") do
    expect_offense(<<~RUBY)
      5.in?((1..10))
      ^^^^^^^^^^^^^^ Use `Range#cover?` instead of `Object#in?`.
    RUBY
  end

  it("registers an offense when using &.in? with a range in parentheses") do
    expect_offense(<<~RUBY)
      5&.in?((1..10))
      ^^^^^^^^^^^^^^^ Use `Range#cover?` instead of `Object#in?`.
    RUBY
  end

  it("does not register an offense when using Range#cover?") do
    expect_no_offenses(<<~RUBY)
      (1..10).cover?(5)
    RUBY
  end

  it("does not register an offense when using Object#in? with a non-range argument") do
    expect_no_offenses(<<~RUBY)
      5.in?([1, 2, 3, 4, 5])
    RUBY
  end

  it("does not register an offense when using &.in? with a non-range argument") do
    expect_no_offenses(<<~RUBY)
      5&.in?([1, 2, 3, 4, 5])
    RUBY
  end
end
