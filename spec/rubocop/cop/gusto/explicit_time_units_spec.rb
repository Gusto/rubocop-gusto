# typed: false
# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::ExplicitTimeUnits, :config do
  describe "enforcing a time unit" do
    context "when a time unit is present" do
      describe "addition" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            DateTime.now + 1.day
          RUBY
        end
      end

      describe "subtraction" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            Time.now - 1.day
          RUBY
        end
      end

      describe "floats" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            Date.today + 2.5.months
          RUBY
        end
      end

      describe "time unit addition" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            6.hours + 100
          RUBY
        end
      end

      describe "method call" do
        it "does not register an offense" do
          def test_method(date)
          end

          expect_no_offenses(<<~RUBY)
            test_method(date)
          RUBY
        end
      end

      describe "addition with variable and time unit" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            count = 5
            DateTime.now + count.days
          RUBY
        end
      end

      describe "let statements" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            count = 5
            DateTime.now + count
          RUBY
        end
      end
    end

    context "when a time unit is not present" do
      describe "addition" do
        it "registers an offense" do
          expect_offense(<<~RUBY)
            DateTime.now + 1000
            ^^^^^^^^^^^^^^^^^^^ Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end

        it "fails when using helpers" do
          expect_offense(<<~RUBY)
            DateTime.beginning_of_week + 1000
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end

      describe "subtraction" do
        it "registers an offense" do
          expect_offense(<<~RUBY)
            Time.now - 2000
            ^^^^^^^^^^^^^^^ Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end

      describe "floats" do
        it "registers an offense" do
          expect_offense(<<~RUBY)
            Date.today - 2.5
            ^^^^^^^^^^^^^^^^ Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end

      describe "constant" do
        it "registers an offense" do
          expect_offense(<<~RUBY)
            OFFSET = 50
            Date.today + OFFSET
            ^^^^^^^^^^^^^^^^^^^ Avoid adding/subtracting integers or floats directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end
    end

    describe "edge cases" do
      context "when using other date time methods" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            DateTime.now.to_s + " is the current date"
          RUBY
        end
      end

      describe "non-date/time arithmetic operations" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            value = 0
            5 + 5
            value += 5
          RUBY
        end
      end

      context "when no arithmetic" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            DateTime.now
          RUBY
        end
      end

      context "when the receiver is not a date/time type" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            [1, 2, 3] + [4, 5, 6]
          RUBY
        end
      end

      context "when the receiver is nil" do
        it "does not register an offense" do
          expect_no_offenses(<<~RUBY)
            + 5
          RUBY
        end
      end
    end
  end
end
