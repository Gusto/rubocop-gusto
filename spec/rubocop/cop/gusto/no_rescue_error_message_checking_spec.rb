# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::NoRescueErrorMessageChecking, :config do
  it do
    expect_no_offenses(<<~RUBY)
      def foo
        business_logic
      rescue => e
        raise CustomError
      end

      def bar
        business_logic
      rescue StandardError => e
        raise CustomError
      rescue => e
        Gusto::Observability::ErrorTracking.notify_error(e, nil)
      end
    RUBY
  end

  it do
    expect_offense(<<~RUBY)
      begin
        business_logic
      rescue => e
        if e.message == 'message'
        ^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end

        if 'message' == e.message
        ^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end
      end
    RUBY
  end

  it "if condition matching exception message" do
    expect_offense(<<~RUBY)
      begin
        business_logic
      rescue => e
        if e.message.match?(/pattern/)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end

        if /inverse_pattern/.match?(e.message)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end
      end
    RUBY
  end

  it "unless condition matching exception message" do
    expect_offense(<<~RUBY)
      begin
        business_logic
      rescue => e
        unless e.message.match?(/pattern/)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end

        unless /inverse_pattern/.match?(e.message)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end
      end
    RUBY
  end

  it "if condition including exception message" do
    expect_offense(<<~RUBY)
      begin
        business_logic
      rescue => e
        if e.message.include?('pattern')
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end

        if ['pattern1', 'pattern2'].include?(e.message)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end
      end
    RUBY
  end

  it "unless condition including exception message" do
    expect_offense(<<~RUBY)
      begin
        business_logic
      rescue => e
        unless e.message.include?('pattern')
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end

        unless ['pattern1', 'pattern2'].include?(e.message)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          # handle error
        end
      end
    RUBY
  end

  it "does not register an offense for other conditions" do
    expect_no_offenses(<<~RUBY)
      begin
        # some code
      rescue => e
        if e.class == StandardError
          # handle standard error
        end
      end
    RUBY
  end

  it "does not register an offense if there is no message check" do
    expect_no_offenses(<<~RUBY)
      begin
        # some code
      rescue => e
        # handle error
      end
    RUBY
  end

  context "with edge cases" do
    it "does not register an offense with a ternary in an array" do
      expect_no_offenses(<<~RUBY)
        begin
          # some code
        rescue => e
          [a ? e.message : e.errors ] # never do this
        end
      RUBY
    end

    it "does not register an offense with a ternary with comparison" do
      expect_no_offenses(<<~RUBY)
        begin
          # some code
        rescue => e
          (a ? e.message : e.errors) == 'message' # never do this
        end
      RUBY
    end

    it "registers an offense with a return if statement" do
      expect_offense(<<~RUBY)
        begin
          # some code
        rescue => e
          return if e.message # never do this
        end

        begin
          # some code
        rescue => e
          return if e.message == 'message'
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
        end
      RUBY
    end

    it "permits a non-return conditional" do
      expect_no_offenses(<<~RUBY)
        begin
          # some code
        rescue => e
          return if e.message # never do this
        end

        begin
          # some code
        rescue => e
          e unless (e.message)
        end
      RUBY
    end

    # Test first condition: condition_node.condition&.send_type?
    it "ignores rescue blocks without send type conditions" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if true # not a send type
            handle_error
          end
        end
      RUBY
    end

    # Test second condition: METHODS_TO_CHECK.include?(condition_node.condition.method_name)
    it "ignores rescue blocks with non-matching method names" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if e.message.empty? # using 'empty?' which is not in METHODS_TO_CHECK
            handle_error
          end
        end
      RUBY
    end

    # Test third condition: condition_node.condition&.receiver
    it "ignores rescue blocks without a receiver" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if nil? # method call without receiver
            handle_error
          end
        end
      RUBY
    end

    # Test when all conditions pass (should raise offense)
    it "registers an offense for error message checking with include?" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if e.message.include?("error")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
          handle_error
          end
        end
      RUBY
    end

    it "registers an offense for error message checking with include? when there is an ensure block" do
      expect_offense(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if e.message.include?("error")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid checking error message while handling exceptions. This is brittle and can break easily.
            handle_error
          end
        ensure
          something_else
        end
      RUBY
    end

    # Test when condition_node.condition is nil
    it "ignores rescue blocks when condition is nil" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if ()  # creates a condition_node with nil condition
            handle_error
          end
        end
      RUBY
    end

    # Test when condition_node.condition exists but receiver is nil
    it "ignores rescue blocks when condition has no receiver" do
      expect_no_offenses(<<~RUBY)
        begin
          something
        rescue StandardError => e
          if include?("error")  # method call without explicit receiver
            handle_error
          end
        end
      RUBY
    end

    it "allows using METHODS_TO_CHECK inside blocks that have a rescue" do
      expect_no_offenses(<<~RUBY)
        begin
          2.times do
            next if [:apples].include?(:bananas)
          end
        rescue StandardError => e
          handle_error
        end
      RUBY
    end
  end
end
