# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::PluckOnSelect, :config do
  it "registers an offense for pluck on select" do
    expect_offense(<<~RUBY)
      User.select(:id).pluck(:id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "registers an offense for pluck on select with a string column" do
    expect_offense(<<~RUBY)
      User.select('id').pluck(:id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "registers an offense for pluck on select with a column alias" do
    expect_offense(<<~RUBY)
      User.select('id AS id2').pluck('id2')
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "registers an offense for pluck on select with DISTINCT" do
    expect_offense(<<~RUBY)
      User.select('DISTINCT id').pluck(:id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "registers an offense when select is higher up in the receiver chain" do
    expect_offense(<<~RUBY)
      User.select('id AS id2').distinct.pluck(:id2)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "registers an offense for pluck on select with a block filter" do
    expect_offense(<<~RUBY)
      User.select(&:active?).pluck(:id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "registers an offense for pluck on select using safe navigation" do
    expect_offense(<<~RUBY)
      User&.select(:id)&.pluck(:id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `.pluck` on `.select`.
    RUBY
  end

  it "does not register an offense for pluck without select" do
    expect_no_offenses(<<~RUBY)
      User.pluck(:id)
    RUBY
  end

  it "does not register an offense for pluck without a receiver" do
    expect_no_offenses(<<~RUBY)
      pluck(:id)
    RUBY
  end
end
