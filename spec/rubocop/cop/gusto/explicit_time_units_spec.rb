# typed: false
# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::ExplicitTimeUnits, :config do
  describe 'enforcing a time unit' do
    context 'when a time unit is present' do
      describe 'addition' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            DateTime.now + 1.day
          RUBY
        end
      end

      describe 'subtraction' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            Time.now - 1.day
          RUBY
        end
      end

      describe 'left shift' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            Date.today << 2.months
          RUBY
        end
      end

      describe 'right shift' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            Date.today >> 3.months
          RUBY
        end
      end
    end

    context 'when a time unit is not present' do
      describe 'addition' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            DateTime.now + 1000
            ^^^^^^^^^^^^^^^^^^^ Avoid adding/subtracting integers directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end

      describe 'subtraction' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            Time.now - 2000
            ^^^^^^^^^^^^^^^ Avoid adding/subtracting integers directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end

      describe 'left shift' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            Date.today << 2
            ^^^^^^^^^^^^^^^ Avoid adding/subtracting integers directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end

      describe 'right shift' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            Date.today >> 3
            ^^^^^^^^^^^^^^^ Avoid adding/subtracting integers directly to Date/Time/DateTime. Use explicit time methods instead (e.g., `.days`, `.hours`).
          RUBY
        end
      end
    end
  end
end
