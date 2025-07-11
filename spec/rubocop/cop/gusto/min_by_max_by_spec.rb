# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::MinByMaxBy, :config do
  it 'registers an offense for min with a proc and corrects it to min_by' do
    expect_offense(<<~RUBY)
      arr.min &:count
      ^^^^^^^^^^^^^^^ Use `min_by` instead of `min` with a proc like `&:my_method_proc`. `min` expects Comparable elements.
    RUBY

    expect_correction(<<~RUBY)
      arr.min_by &:count
    RUBY
  end

  it 'registers an offense for min with a proc in a chain and corrects it to min_by' do
    expect_offense(<<~RUBY)
      arr.min(&:count).map(&:to_s)
      ^^^^^^^^^^^^^^^^ Use `min_by` instead of `min` with a proc like `&:my_method_proc`. `min` expects Comparable elements.
    RUBY

    expect_correction(<<~RUBY)
      arr.min_by(&:count).map(&:to_s)
    RUBY
  end

  it 'registers an offense for max with a proc and corrects it to max_by' do
    expect_offense(<<~RUBY)
      arr.max(&:length)
      ^^^^^^^^^^^^^^^^^ Use `max_by` instead of `max` with a proc like `&:my_method_proc`. `max` expects Comparable elements.
    RUBY

    expect_correction(<<~RUBY)
      arr.max_by(&:length)
    RUBY
  end

  it 'does not register an offense for min without a proc' do
    expect_no_offenses(<<~RUBY)
      arr.min
    RUBY
  end

  it 'does not register an offense for min with both an argument and a proc' do
    # NOTE: This is still very likely to be problematic, but it's beyond the scope of this cop.
    # https://apidock.com/ruby/Enumerable/min
    # https://ruby-doc.org/3.3.5/Enumerable.html#method-i-min
    expect_no_offenses(<<~RUBY)
      arr.min(3, &:count)
    RUBY
  end

  it 'does not register an offense for min with a Comparable block' do
    expect_no_offenses(<<~RUBY)
      arr.min { |a, b| a.count <=> b.count }
    RUBY
  end

  it 'does not register an offense for max without a proc' do
    expect_no_offenses(<<~RUBY)
      arr.max
    RUBY
  end

  it 'does not register an offense for max with a numeric argument (a limit)' do
    expect_no_offenses(<<~RUBY)
      arr.max(3)
    RUBY
  end

  it 'does not register an offense for max with a Comparable block' do
    expect_no_offenses(<<~RUBY)
      arr.max {|a, b| a.length <=> b.length }
    RUBY
  end

  it 'does not register an offense for max with an empty block' do
    expect_no_offenses(<<~RUBY)
      arr.max { }
    RUBY
  end

  it 'does not register an offense for max with a multiline block' do
    expect_no_offenses(<<~RUBY)
      arr.max do |a, b|
        # Comparator here
      end
    RUBY
  end

  it 'does not register an offense for min_by with a proc' do
    expect_no_offenses(<<~RUBY)
      arr.min_by(&:count)
    RUBY
  end

  it 'does not register an offense for max_by with a proc' do
    expect_no_offenses(<<~RUBY)
      arr.max_by(&:count)
    RUBY
  end
end
