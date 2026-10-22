# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::TimeoutTimeout, :config do
  it "registers an offense for Timeout.timeout with a block" do
    expect_offense(<<~RUBY)
      Timeout.timeout(5) { do_work }
      ^^^^^^^^^^^^^^^^^^ Avoid `Timeout.timeout`; it interrupts the block with `Thread#raise` at an arbitrary point. Use the timeout option of the operation being waited on instead.
    RUBY
  end

  it "registers an offense for a top-level Timeout constant and a custom error class" do
    expect_offense(<<~RUBY)
      ::Timeout.timeout(5, MyError) do
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid `Timeout.timeout`; it interrupts the block with `Thread#raise` at an arbitrary point. Use the timeout option of the operation being waited on instead.
        do_work
      end
    RUBY
  end

  it "registers an offense for the double-colon call form" do
    expect_offense(<<~RUBY)
      Timeout::timeout(5) { do_work }
      ^^^^^^^^^^^^^^^^^^^ Avoid `Timeout.timeout`; it interrupts the block with `Thread#raise` at an arbitrary point. Use the timeout option of the operation being waited on instead.
    RUBY
  end

  it "does not register an offense for a namespaced Timeout constant" do
    expect_no_offenses(<<~RUBY)
      MyApp::Timeout.timeout(5)
    RUBY
  end

  it "does not register an offense for a timeout method on another receiver" do
    expect_no_offenses(<<~RUBY)
      client.timeout(5)
      timeout(5)
    RUBY
  end

  it "does not register an offense for rescuing Timeout::Error" do
    expect_no_offenses(<<~RUBY)
      begin
        http.get(path)
      rescue Timeout::Error
        retry
      end
    RUBY
  end
end
