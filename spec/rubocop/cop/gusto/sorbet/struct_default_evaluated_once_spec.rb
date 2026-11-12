# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Sorbet::StructDefaultEvaluatedOnce, :config do
  describe "defaults that read the clock or a random source" do
    it "registers an offense for Time.zone.now and corrects it to a factory" do
      expect_offense(<<~RUBY)
        class Shift < T::Struct
          const :started_at, Time, default: Time.zone.now
                                   ^^^^^^^^^^^^^^^^^^^^^^ `default:` is evaluated once, when the class loads, so every instance shares this value. Use `factory: -> { Time.zone.now }` to compute it per instance.
        end
      RUBY

      expect_correction(<<~RUBY)
        class Shift < T::Struct
          const :started_at, Time, factory: -> { Time.zone.now }
        end
      RUBY
    end

    it "registers an offense for SecureRandom on a prop and keeps the other options" do
      expect_offense(<<~RUBY)
        class Shift < T::Struct
          prop :uuid, String, default: SecureRandom.uuid, override: true
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^ `default:` is evaluated once, [...]
        end
      RUBY

      expect_correction(<<~RUBY)
        class Shift < T::Struct
          prop :uuid, String, factory: -> { SecureRandom.uuid }, override: true
        end
      RUBY
    end

    [
      "Time.now",
      "::Time.current",
      "Time.zone.today",
      "Date.today",
      "Date.current",
      "DateTime.now",
      "Time.current.beginning_of_day",
      "1.day.ago",
      "2.hours.from_now",
      "Random.rand(10)",
      "rand(10)",
    ].each do |value|
      it "registers an offense for `#{value}`" do
        expect_offense(<<~RUBY, value:)
          class Shift < T::Struct
            const :at, Time, default: %{value}
                             ^^^^^^^^^^{value} `default:` is evaluated once, [...]
          end
        RUBY
      end
    end
  end

  describe "defaults that are safe to evaluate once" do
    [
      "nil",
      "false",
      "'ACTIVE'",
      "[]",
      "{}",
      "1.day",
      'BigDecimal("0")',
      "Time.zone.parse('2024-01-01')",
      "1.day.ago(Time.zone.parse('2024-01-01'))",
      "since",
    ].each do |value|
      it "does not register an offense for `#{value}`" do
        expect_no_offenses(<<~RUBY)
          class Shift < T::Struct
            const :value, T.untyped, default: #{value}
          end
        RUBY
      end
    end

    it "does not register an offense for a factory" do
      expect_no_offenses(<<~RUBY)
        class Shift < T::Struct
          const :started_at, Time, factory: -> { Time.zone.now }
        end
      RUBY
    end

    it "does not register an offense for clock reads inside a lambda passed as the default" do
      expect_no_offenses(<<~RUBY)
        class Shift < T::Struct
          const :clock, T.proc.returns(Time), default: -> { Time.zone.now }
        end
      RUBY
    end

    it "does not register an offense for clock reads inside a numbered-parameter block" do
      expect_no_offenses(<<~RUBY)
        class Shift < T::Struct
          const :clock, T.untyped, default: proc { Time.zone.now + _1 }
        end
      RUBY
    end

    it "does not register an offense for a const with no options" do
      expect_no_offenses(<<~RUBY)
        class Shift < T::Struct
          const :started_at, Time
        end
      RUBY
    end

    it "does not register an offense for a bare const call" do
      expect_no_offenses(<<~RUBY)
        const
      RUBY
    end

    it "does not register an offense for options without a default" do
      expect_no_offenses(<<~RUBY)
        class Shift < T::Struct
          const :started_at, Time, override: true
        end
      RUBY
    end

    it "does not register an offense for a string-keyed default" do
      expect_no_offenses(<<~RUBY)
        class Shift < T::Struct
          const :started_at, Time, "default" => Time.zone.now
        end
      RUBY
    end

    it "does not register an offense when the method has an explicit receiver" do
      expect_no_offenses(<<~RUBY)
        builder.const :started_at, Time, default: Time.zone.now
      RUBY
    end

    it "does not register an offense for a safe-navigation call" do
      expect_no_offenses(<<~RUBY)
        builder&.const :started_at, Time, default: Time.zone.now
      RUBY
    end
  end
end
