# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Sorbet::PredicateBooleanReturn, :config do
  context "when the file is Sorbet-typed" do
    context "with methods returning nil" do
      it "registers an offense for predicate methods with void return type" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { void }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              nil
            end
          end
        RUBY
      end

      it "registers an offense for predicate methods with T.nilable return type" do
        expect_offense(<<~RUBY)
          # typed: strict
          class Foo
            sig { returns(T.nilable(String)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              'yes' || nil
            end
          end
        RUBY
      end

      it "registers an offense for predicate methods with T.any including nil" do
        expect_offense(<<~RUBY)
          # typed: strong
          class Foo
            sig { returns(T.any(String, NilClass)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              nil
            end
          end
        RUBY
      end
    end

    context "with methods returning non-boolean values" do
      it "registers an offense for predicate methods returning String" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              'yes'
            end
          end
        RUBY
      end

      it "registers an offense for predicate methods returning Integer" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(Integer) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns Integer instead of boolean.
              1
            end
          end
        RUBY
      end

      it "registers an offense for predicate methods returning T.untyped" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.untyped) }
            def empty?
            ^^^^^^^^^^ Predicate method `empty?` returns T.untyped instead of boolean.
              @items.empty?
            end
          end
        RUBY
      end
    end

    context "with valid predicate methods" do
      it "does not register an offense for methods returning T::Boolean" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register an offense for methods returning T.any(TrueClass, FalseClass)" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(TrueClass, FalseClass)) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register an offense for non-predicate methods" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def validate
              'yes'
            end
          end
        RUBY
      end
    end

    context "with class methods" do
      it "registers an offense for class predicate methods with non-boolean return" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def self.valid?
            ^^^^^^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              'yes'
            end
          end
        RUBY
      end

      it "does not register an offense for class predicate methods with boolean return" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def self.valid?
              true
            end
          end
        RUBY
      end
    end

    context "with private methods" do
      it "registers an offense for private predicate methods with non-boolean return" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            private

            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              'yes'
            end
          end
        RUBY
      end
    end

    context "with private class methods" do
      it "registers an offense for private_class_method inline with def self" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            private_class_method def self.company_active?(company)
                                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Predicate method `company_active?` returns String instead of boolean.
              "yes"
            end
          end
        RUBY
      end

      it "registers an offense for private_class_method declared after method" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(Integer) }
            def self.valid?
            ^^^^^^^^^^^^^^^ Predicate method `valid?` returns Integer instead of boolean.
              1
            end
            private_class_method :valid?
          end
        RUBY
      end

      it "registers an offense for methods in class << self with private" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            class << self
              private

              sig { returns(String) }
              def active?
              ^^^^^^^^^^^ Predicate method `active?` returns String instead of boolean.
                "yes"
              end
            end
          end
        RUBY
      end

      it "registers an offense for singleton class private methods" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.nilable(String)) }
            def self.enabled?
            ^^^^^^^^^^^^^^^^^ Predicate method `enabled?` may return nil instead of boolean.
              nil
            end

            singleton_class.send(:private, :enabled?)
          end
        RUBY
      end

      it "does not register an offense for private class predicate methods with boolean return" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            private_class_method def self.company_active?(company)
              company.active?
            end
          end
        RUBY
      end

      it "does not register an offense for private methods in class << self with boolean return" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            class << self
              private

              sig { returns(T::Boolean) }
              def active?
                true
              end
            end
          end
        RUBY
      end

      it "registers an offense for multiple private class methods" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def self.active?
            ^^^^^^^^^^^^^^^^ Predicate method `active?` returns String instead of boolean.
              "yes"
            end

            sig { returns(Integer) }
            def self.valid?
            ^^^^^^^^^^^^^^^ Predicate method `valid?` returns Integer instead of boolean.
              1
            end

            private_class_method :active?, :valid?
          end
        RUBY
      end
    end

    context "with methods without signatures" do
      it "does not register an offense for predicate methods without signatures" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            def valid?
              'yes'
            end
          end
        RUBY
      end
    end
  end

  context "when the file is not Sorbet-typed" do
    it "does not register an offense regardless of return type" do
      expect_no_offenses(<<~RUBY)
        # typed: false
        class Foo
          sig { returns(String) }
          def valid?
            'yes'
          end
        end
      RUBY
    end

    it "does not register an offense in files without typed sigil" do
      expect_no_offenses(<<~RUBY)
        class Foo
          sig { returns(String) }
          def valid?
            'yes'
          end
        end
      RUBY
    end

    it "does not register an offense in typed: ignore files" do
      expect_no_offenses(<<~RUBY)
        # typed: ignore
        class Foo
          sig { returns(String) }
          def valid?
            'yes'
          end
        end
      RUBY
    end
  end

  context "with module methods" do
    it "registers an offense for module predicate methods with non-boolean return" do
      expect_offense(<<~RUBY)
        # typed: true
        module Foo
          sig { returns(String) }
          def self.active?
          ^^^^^^^^^^^^^^^^ Predicate method `active?` returns String instead of boolean.
            "yes"
          end
        end
      RUBY
    end

    it "registers an offense for module extend self predicate methods" do
      expect_offense(<<~RUBY)
        # typed: true
        module Foo
          extend self

          sig { returns(String) }
          def active?
          ^^^^^^^^^^^ Predicate method `active?` returns String instead of boolean.
            "yes"
          end
        end
      RUBY
    end
  end

  context "with wrapped/decorated methods" do
    it "does not register an offense for attr_memoized predicate methods without signatures" do
      expect_no_offenses(<<~RUBY)
        # typed: true
        class Foo
          attr_memoized def has_international_contractors?
            company.international_contractors.exists?
          end
        end
      RUBY
    end

    it "does not register an offense for attr_memoized predicate methods even with bad signatures" do
      expect_no_offenses(<<~RUBY)
        # typed: true
        class Foo
          attr_memoized def has_international_contractors?
            # This would normally trigger an offense if not wrapped, but should be skipped
            "yes"
          end
        end
      RUBY
    end

    it "does not register an offense for other decorated predicate methods" do
      expect_no_offenses(<<~RUBY)
        # typed: true
        class Foo
          some_decorator def decorated_method?
            false
          end
        end
      RUBY
    end

    it "does not register an offense for memoize decorated predicate methods" do
      expect_no_offenses(<<~RUBY)
        # typed: true
        class Foo
          memoize def cached_valid?
            expensive_validation
          end
        end
      RUBY
    end

    it "does not register an offense for delegate decorated predicate methods" do
      expect_no_offenses(<<~RUBY)
        # typed: true
        class Foo
          delegate def enabled?
            user.enabled?
          end
        end
      RUBY
    end

    it "still processes private_class_method decorated methods normally" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(String) }
          private_class_method def self.valid?
                               ^^^^^^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
            'yes'
          end
        end
      RUBY
    end

    it "still processes methods without decorators normally" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(String) }
          def valid?
          ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
            'yes'
          end
        end
      RUBY
    end
  end

  context "when autocorrecting" do
    it "corrects signature and coerces string return" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(String) }
          def valid?
          ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
            "yes"
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) }
          def valid?
            !!("yes")
          end
        end
      RUBY
    end

    it "corrects signature and coerces integer return" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(Integer) }
          def active?
          ^^^^^^^^^^^ Predicate method `active?` returns Integer instead of boolean.
            1
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) }
          def active?
            !!(1)
          end
        end
      RUBY
    end

    it "corrects signature and coerces nilable return" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T.nilable(String)) }
          def present?
          ^^^^^^^^^^^^ Predicate method `present?` may return nil instead of boolean.
            @value
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) }
          def present?
            !!(@value)
          end
        end
      RUBY
    end

    it "corrects void signature and nil literal body to false" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { void }
          def complete?
          ^^^^^^^^^^^^^ Predicate method `complete?` may return nil instead of boolean.
            nil
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) }
          def complete?
            false
          end
        end
      RUBY
    end

    it "corrects T.untyped signature and coerces return" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T.untyped) }
          def configured?
          ^^^^^^^^^^^^^^^ Predicate method `configured?` returns T.untyped instead of boolean.
            @config_value
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) }
          def configured?
            !!(@config_value)
          end
        end
      RUBY
    end

    it "does not double-coerce already coerced expression" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T.untyped) } # Incorrect sig, but body is already !!
          def check?
          ^^^^^^^^^^ Predicate method `check?` returns T.untyped instead of boolean.
            !!compute_check
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) } # Incorrect sig, but body is already !!
          def check?
            !!compute_check
          end
        end
      RUBY
    end

    it "corrects private class method" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(String) }
          private_class_method def self.company_active?(company)
                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Predicate method `company_active?` returns String instead of boolean.
            "active"
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          sig { returns(T::Boolean) }
          private_class_method def self.company_active?(company)
            !!("active")
          end
        end
      RUBY
    end

    it "corrects method in class << self" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          class << self
            private
            sig { returns(String) }
            def bar?
            ^^^^^^^^ Predicate method `bar?` returns String instead of boolean.
              "value"
            end
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        # typed: true
        class Foo
          class << self
            private
            sig { returns(T::Boolean) }
            def bar?
              !!("value")
            end
          end
        end
      RUBY
    end

    it "registers offense but does not correct signature or body for empty void methods" do
      expect_offense(<<~RUBY)
        # typed: true
        class Foo
          sig { void }
          def empty_body?
          ^^^^^^^^^^^^^^^ Predicate method `empty_body?` may return nil instead of boolean.
          end
        end
      RUBY

      expect_no_corrections
    end
  end

  context "with edge cases and additional coverage" do
    context "with boolean coercion detection" do
      it "detects already coerced expressions with !!" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!some_method
            end
          end
        RUBY
      end

      it "detects single negation expressions" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              !some_method
            end
          end
        RUBY

        # Should not add coercion as it already starts with !
        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !some_method
            end
          end
        RUBY
      end

      it "does not treat != as negation" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              x != y
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(x != y)
            end
          end
        RUBY
      end
    end

    context "with various method body types" do
      it "handles multi-statement method bodies" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              setup_something
              "result"
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              setup_something
              !!("result")
            end
          end
        RUBY
      end

      it "does not register empty method bodies gracefully" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
            end
          end
        RUBY
      end
    end

    context "with type checking edge cases" do
      it "does not register T::Boolean constant" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register standalone Boolean constant" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(Boolean) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register TrueClass constant" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(TrueClass) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register FalseClass constant" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(FalseClass) }
            def valid?
              false
            end
          end
        RUBY
      end

      it "rejects T.any with wrong number of arguments" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(String, Integer, Symbol)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(String, Integer, Symbol) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "rejects T.any with non-boolean types" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(String, Integer)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(String, Integer) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles direct NilClass constant" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(NilClass) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              nil
            end
          end
        RUBY
      end

      it "handles non-T send types" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(SomeOtherClass.some_method) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns SomeOtherClass.some_method instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles unknown T methods" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.unknown_method) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.unknown_method instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles complex const chains" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(Some::Complex::Type) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns Some::Complex::Type instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles non-const, non-send types" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(1) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns 1 instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "with sig node detection edge cases" do
      it "does not register non-block nodes gracefully" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            some_call
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register nodes without block_type? method" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            CONSTANT = "value"
            def valid?
              true
            end
          end
        RUBY
      end

      it "stops at non-private method calls" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            some_other_call
            def valid?
              true
            end
          end
        RUBY
      end

      it "skips multiple private calls to find sig" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            private
            private
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              "yes"
            end
          end
        RUBY
      end
    end

    context "with signature extraction edge cases" do
      it "does not register sigs without returns or void" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { params(x: String) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "does not register empty sig blocks" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { }
            def valid?
              true
            end
          end
        RUBY
      end
    end

    context "with nilable type detection" do
      it "detects T.any with NilClass in different positions" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(NilClass, String)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              nil
            end
          end
        RUBY
      end

      it "handles send nodes that are not T.nilable or T.any" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(SomeClass.some_method) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns SomeClass.some_method instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "with autocorrection specific cases" do
      it "does not register methods with no first_argument on returns" do
        # This should not happen in valid code, but we should handle it gracefully
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            def valid?
              true
            end
          end
        RUBY
      end
    end

    context "when calling returns_nil? directly" do
      it "returns false for return nodes that are neither void nor returns" do
        # This tests the implicit else branch: return_node is neither :void nor :returns
        cop = described_class.new

        # Create a mock return node that responds to method? with false for both :void and :returns
        return_node = instance_double(RuboCop::AST::SendNode)
        allow(return_node).to receive(:method?).with(:void).and_return(false)
        allow(return_node).to receive(:method?).with(:returns).and_return(false)

        result = cop.__send__(:returns_nil?, return_node)
        expect(result).to be(false)
      end
    end

    context "with different decorators" do
      it "skips methods with custom decorators" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            custom_decorator def wrapped_method?
              "should be skipped"
            end
          end
        RUBY
      end

      it "skips methods with alias_method wrapper" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            alias_method def aliased_method?
              "should be skipped"
            end
          end
        RUBY
      end

      it "does not register methods without parent gracefully" do
        # This tests the edge case where method_node.parent is nil
        expect_no_offenses(<<~RUBY)
          # typed: true
          def standalone_method?
            true
          end
        RUBY
      end
    end

    context "with type formatting edge cases" do
      it "handles T.nilable with nil argument" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.nilable(nil)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              nil
            end
          end
        RUBY
      end

      it "handles empty T.any" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any()) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any() instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "with return type edge cases" do
      it "does not register methods without signatures gracefully" do
        # Edge case that shouldn't happen in valid Sorbet but we should handle gracefully
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            def valid?
              true
            end
          end
        RUBY
      end
    end

    context "with specific regex and pattern matching" do
      it "handles != operator correctly" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              x != y
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(x != y)
            end
          end
        RUBY
      end

      it "handles !~ operator correctly" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              x !~ /pattern/
            end
          end
        RUBY

        # The regex pattern actually allows this through as it's !~ (negation pattern match)
        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(x !~ /pattern/)
            end
          end
        RUBY
      end
    end

    context "with find_sig_node safety mechanisms" do
      it "does not register deeply nested private calls without hanging" do
        # Create a scenario that could trigger the safety guard
        deep_private_calls = Array.new(60) { "private" }.join("\n    ")
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            #{deep_private_calls}
            def valid?
              true
            end
          end
        RUBY
      end
    end

    context "with extract_const_name edge cases" do
      it "handles non-const nodes gracefully" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns("literal_string") }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns "literal_string" instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "with method parent edge cases" do
      it "does not register methods with non-send parents" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            if some_condition
              def valid?
                true
              end
            end
          end
        RUBY
      end
    end

    context "without a receiver" do
      it "handles send nodes without receivers in type checking" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(some_method_call) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns some_method_call instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles send nodes in boolean_type? without T receiver" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(SomeClass.any(String, Integer)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns SomeClass.any(String, Integer) instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "with complex T.any cases" do
      it "handles T.any with one argument" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(String)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(String) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles T.any with non-const arguments" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(some_call, other_call)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(some_call, other_call) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles T.any with mixed const and non-const" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(TrueClass, some_call)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(TrueClass, some_call) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles T.any with T.nilable inside (tests format_send_type nilable branch)" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(T.nilable(String), Integer)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(T.nilable(String), Integer) instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "with private_class_method edge cases" do
      it "does not register private_class_method without left sibling" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            private_class_method def self.valid?
              true
            end
          end
        RUBY
      end
    end

    context "with nilable type edge cases for non-T senders" do
      it "handles non-T.nilable send nodes" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(SomeClass.nilable(String)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              true
            end
          end
        RUBY
      end
    end

    context "when the on_defs hook returns early" do
      it "returns early for non-predicate class methods" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def self.validate
              'not a predicate method'
            end
          end
        RUBY
      end

      it "returns early for class methods in untyped files" do
        expect_no_offenses(<<~RUBY)
          # typed: false
          class Foo
            sig { returns(String) }
            def self.valid?
              'untyped file'
            end
          end
        RUBY
      end

      it "returns early for class methods without typed sigil" do
        expect_no_offenses(<<~RUBY)
          class Foo
            sig { returns(String) }
            def self.valid?
              'no typed sigil'
            end
          end
        RUBY
      end

      it "returns early for class methods in ignore files" do
        expect_no_offenses(<<~RUBY)
          # typed: ignore
          class Foo
            sig { returns(String) }
            def self.valid?
              'ignore file'
            end
          end
        RUBY
      end
    end

    context "when the on_def hook returns early" do
      it "returns early for non-predicate instance methods" do
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def validate
              'not a predicate method'
            end
          end
        RUBY
      end

      it "returns early for instance methods in untyped files" do
        expect_no_offenses(<<~RUBY)
          # typed: false
          class Foo
            sig { returns(String) }
            def valid?
              'untyped file'
            end
          end
        RUBY
      end
    end

    context "with comprehensive branch coverage" do
      it "handles void methods that are not empty" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { void }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              puts "something"
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(puts "something")
            end
          end
        RUBY
      end

      it "handles non-void methods with nil body" do
        # This tests the branch where first condition is false, second is true
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              nil
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(nil)
            end
          end
        RUBY
      end

      it "handles non-void methods with empty body (tests safe navigation)" do
        # This tests the safe navigation &. in method_body&.nil_type?
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
            end
          end
        RUBY

        # Empty body methods just get signature correction, no body coercion
        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
            end
          end
        RUBY
      end

      it "does not register return_type_node methods other than returns/void" do
        # Testing the else branch in returns_nil?
        expect_no_offenses(<<~RUBY)
          # typed: true
          class Foo
            sig { params(x: String) }
            def valid?
              true
            end
          end
        RUBY
      end

      it "handles nodes without first_argument in nilable_type?" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns unknown instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles nodes without first_argument in format_send_type" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.nilable) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles format_type_arg with nil return from extract_const_name" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns([1, 2, 3]) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns [1, 2, 3] instead of boolean.
              true
            end
          end
        RUBY
      end

      it "covers non-const type in extract_const_name" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(some_variable) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns some_variable instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles T.boolean (different from T::Boolean)" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.boolean) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.boolean instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles const without T prefix in extract_const_name" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(SomeModule::SomeClass) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns SomeModule::SomeClass instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles boolean_type? with non-const args in T.any" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.any(some_call, TrueClass)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.any(some_call, TrueClass) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles send nodes with nil receiver in boolean_type?" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(any(TrueClass, FalseClass)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns any(TrueClass, FalseClass) instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles send nodes with nil receiver in nilable_type?" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(nilable(String)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles send nodes that are not nilable/any in nilable_type?" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.something(String)) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.something instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles nil node argument in format_type_arg" do
        # This covers the case where format_type_arg receives nil
        # We create a scenario where this might happen
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T.complex_type_with_nil_arg) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns T.complex_type_with_nil_arg instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles const nodes without const_type? children" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(::GlobalConst) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns GlobalConst instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles boolean_type? with wrong const receiver" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(NotT::Boolean) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns NotT::Boolean instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles non-const receiver in format_send_type" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(some_var.untyped) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns some_var.untyped instead of boolean.
              true
            end
          end
        RUBY
      end

      it "handles nil receiver in format_send_type" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(untyped) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns untyped instead of boolean.
              true
            end
          end
        RUBY
      end

      it "tests already_boolean_coerced? with operator" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
             [] << !true # This is a boolean expression
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
             !!([] << !true) # This is a boolean expression
            end
          end
        RUBY
      end

      it "tests already_boolean_coerced? with non-send node" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              true
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(true)
            end
          end
        RUBY
      end

      it "tests already_boolean_coerced? with send node but not !" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              some_method
            end
          end
        RUBY

        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !!(some_method)
            end
          end
        RUBY
      end

      it "tests already_boolean_coerced? with ! but no receiver" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              !some_method
            end
          end
        RUBY

        # Should not be coerced as it already starts with !
        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !some_method
            end
          end
        RUBY
      end

      it "tests already_boolean_coerced? with ! receiver but not !" do
        expect_offense(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(String) }
            def valid?
            ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
              !some_method.something
            end
          end
        RUBY

        # Should not be coerced as it already starts with !
        expect_correction(<<~RUBY)
          # typed: true
          class Foo
            sig { returns(T::Boolean) }
            def valid?
              !some_method.something
            end
          end
        RUBY
      end

      context "with already_boolean_coerced? receiver logic" do
        it "handles node.receiver being nil (tests &. safe navigation)" do
          # This tests the case where the receiver is nil - !nil
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !nil
              end
            end
          RUBY

          # Should not be coerced as it starts with !
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !nil
              end
            end
          RUBY
        end

        it "handles receiver that is not send_type (literal values)" do
          # This tests when receiver exists but is not a send node - !true, !false
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !true
              end
            end
          RUBY

          # Should not be coerced as it starts with !
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !true
              end
            end
          RUBY
        end

        it "handles receiver that is send_type but not ! method" do
          # This tests when receiver is a send node but not the ! method - !method_call.empty?
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !some_array.empty?
              end
            end
          RUBY

          # Should not be coerced as it starts with !
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !some_array.empty?
              end
            end
          RUBY
        end

        it "handles receiver that is send_type and is ! method (!! pattern)" do
          # This tests the true case: !!expression - both conditions satisfied
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !!some_expression
              end
            end
          RUBY

          # Should NOT be coerced as it's already !! - this tests the receiver logic
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !!some_expression
              end
            end
          RUBY
        end

        it "handles complex !! patterns with instance variables" do
          # Additional test for complex !! patterns to ensure receiver detection works
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !!@items
              end
            end
          RUBY

          # Should NOT be coerced - receiver&.send_type? && receiver.method?(:!)
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !!@items
              end
            end
          RUBY
        end

        it "handles triple negation (!!!) to test receiver chain" do
          # This tests !!!expression where outer ! has receiver that is !!
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !!!some_value
              end
            end
          RUBY

          # Should not be coerced as it starts with ! (but not detected as !!)
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !!!some_value
              end
            end
          RUBY
        end

        it "handles receiver that exists but is not send_type (instance variable)" do
          # This tests the missing branch: node.receiver exists but !send_type?
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                !@instance_var
              end
            end
          RUBY

          # Should not be coerced as it starts with ! (receiver exists but isn't send_type)
          expect_correction(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(T::Boolean) }
              def valid?
                !@instance_var
              end
            end
          RUBY
        end
      end

      context "with sig_block? detection" do
        it "returns false for blocks that are not sig method calls" do
          # This tests the false branch of node.method?(:sig)
          expect_no_offenses(<<~RUBY)
            # typed: true
            class Foo
              some_other_block { puts "hello" }
              def valid?
                true
              end
            end
          RUBY
        end

        it "returns false for method blocks that are not sig" do
          # This tests when we have a block node but it calls a different method
          expect_no_offenses(<<~RUBY)
            # typed: true
            class Foo
              configure { |config| config.setting = true }
              def valid?
                true
              end
            end
          RUBY
        end

        it "returns true for proper sig blocks and processes them" do
          # This tests the true branch of node.method?(:sig)
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                "yes"
              end
            end
          RUBY
        end

        it "handles multiple non-sig blocks before finding sig" do
          # This tests multiple blocks where only the last one is a sig
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              configure { |c| c.setup }
              validate { |v| v.check }
              sig { returns(String) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns String instead of boolean.
                "result"
              end
            end
          RUBY
        end

        it "does not register methods with no sig blocks at all" do
          # This tests when sig_block? returns false for all blocks
          expect_no_offenses(<<~RUBY)
            # typed: true
            class Foo
              configure { |config| config.value = 1 }
              setup { initialize_something }
              def valid?
                true
              end
            end
          RUBY
        end

        it "does not register nested blocks where inner block is not sig" do
          # This tests complex block structures
          expect_no_offenses(<<~RUBY)
            # typed: true
            class Foo
              around_action { |controller, action|
                begin
                  action.call
                rescue
                  handle_error
                end
              }
              def valid?
                true
              end
            end
          RUBY
        end
      end

      context "with a final edge case for full coverage" do
        it "handles extract_const_name with non-const nodes" do
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { returns(42) }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` returns 42 instead of boolean.
                true
              end
            end
          RUBY
        end

        it "hits safety guard in find_sig_node with many private calls" do
          # Create a scenario that triggers the safety guard (50+ private calls)
          many_privates = Array.new(60) { "private" }.join("\n    ")
          expect_no_offenses(<<~RUBY)
            # typed: true
            class Foo
              #{many_privates}
              def valid?
                true
              end
            end
          RUBY
        end

        it "handles empty body with void method for edge coverage" do
          expect_offense(<<~RUBY)
            # typed: true
            class Foo
              sig { void }
              def valid?
              ^^^^^^^^^^ Predicate method `valid?` may return nil instead of boolean.
              end
            end
          RUBY

          expect_no_corrections
        end
      end
    end
  end
end
