# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::IgnoredColumnsAssignment, :config do
  it 'registers an offense for direct assignment with symbol' do
    expect_offense(<<~RUBY)
      self.ignored_columns = :column_name
           ^^^^^^^^^^^^^^^ Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.
    RUBY
  end

  it 'registers an offense for direct assignment with string' do
    expect_offense(<<~RUBY)
      self.ignored_columns = 'column_name'
           ^^^^^^^^^^^^^^^ Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.
    RUBY
  end

  it 'registers an offense for direct assignment with multiple items' do
    expect_offense(<<~RUBY)
      self.ignored_columns = :column_name, :another_column
           ^^^^^^^^^^^^^^^ Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.
    RUBY
  end

  it 'does not register an offense for += assignment with array' do
    expect_no_offenses(<<~RUBY)
      self.ignored_columns += [:column_name]
    RUBY
  end

  it 'does not register an offense for += assignment with multiple items in array' do
    expect_no_offenses(<<~RUBY)
      self.ignored_columns += [:column_name, :another_column]
    RUBY
  end

  it 'registers an offense for empty array assignment' do
    expect_offense(<<~RUBY)
      self.ignored_columns = []
           ^^^^^^^^^^^^^^^ Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.
    RUBY
  end

  it 'registers an offense for array assignment' do
    expect_offense(<<~RUBY)
      self.ignored_columns = ['column_name']
           ^^^^^^^^^^^^^^^ Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.
    RUBY
  end

  it 'does not register an offense for other ignored_columns usage' do
    expect_no_offenses(<<~RUBY)
      self.ignored_columns
      ignored_columns
    RUBY
  end

  it 'registers an offense for method call assignment' do
    expect_offense(<<~RUBY)
      self.ignored_columns = some_method
           ^^^^^^^^^^^^^^^ Use `+=` with an array for `ignored_columns` assignment instead of direct assignment.
    RUBY
  end
end
