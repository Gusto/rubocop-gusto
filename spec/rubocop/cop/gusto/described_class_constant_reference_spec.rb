# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::DescribedClassConstantReference, :config do
  context "when a constant is scoped through described_class" do
    it "registers an offense and rewrites the describe argument to the fully-qualified constant" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments::Processor do
          describe described_class::Worker do
                   ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments::Processor do
          describe Payments::Processor::Worker do
          end
        end
      RUBY
    end

    it "registers an offense and rewrites a reference inside an example" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments::Processor do
          it "returns the const" do
            expect(described_class::TIMEOUT).to eq(5)
                   ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments::Processor do
          it "returns the const" do
            expect(Payments::Processor::TIMEOUT).to eq(5)
          end
        end
      RUBY
    end

    it "registers a single offense for a deeply nested constant and qualifies the leading scope" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments::Processor do
          it "references a deeply nested const" do
            described_class::Config::Timeout
            ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments::Processor do
          it "references a deeply nested const" do
            Payments::Processor::Config::Timeout
          end
        end
      RUBY
    end

    it "resolves a reference inside an aliased example group (feature)" do
      expect_offense(<<~RUBY)
        RSpec.feature Payments::Processor do
          it "returns the const" do
            expect(described_class::TIMEOUT).to eq(5)
                   ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.feature Payments::Processor do
          it "returns the const" do
            expect(Payments::Processor::TIMEOUT).to eq(5)
          end
        end
      RUBY
    end

    it "resolves against the described constant when the group has extra arguments (metadata)" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments::Processor, :aggregate_failures do
          it "returns the const" do
            expect(described_class::TIMEOUT).to eq(5)
                   ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments::Processor, :aggregate_failures do
          it "returns the const" do
            expect(Payments::Processor::TIMEOUT).to eq(5)
          end
        end
      RUBY
    end

    it "qualifies the leading scope when the described constant is itself multi-segment" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments::Processor do
          describe described_class::Config::Timeout do
                   ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments::Processor do
          describe Payments::Processor::Config::Timeout do
          end
        end
      RUBY
    end

    it "qualifies a reference nested inside a described_class::Const group across passes" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments::Processor do
          describe described_class::Worker do
                   ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
            it "references a constant on the inner class" do
              expect(described_class::SETTING).to be_truthy
                     ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
            end
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments::Processor do
          describe Payments::Processor::Worker do
            it "references a constant on the inner class" do
              expect(Payments::Processor::Worker::SETTING).to be_truthy
            end
          end
        end
      RUBY
    end

    it "resolves to the nearest enclosing example group, which may be a context" do
      expect_offense(<<~RUBY)
        RSpec.describe Payments do
          context Payments::Processor do
            describe described_class::Worker do
                     ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
            end
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        RSpec.describe Payments do
          context Payments::Processor do
            describe Payments::Processor::Worker do
            end
          end
        end
      RUBY
    end
  end

  context "when the described class cannot be resolved lexically" do
    it "registers an offense but does not autocorrect" do
      expect_offense(<<~RUBY)
        RSpec.describe "a collaborator" do
          it "references a constant" do
            described_class::Foo
            ^^^^^^^^^^^^^^^ Use the fully-qualified constant name instead of scoping it through `described_class`, which Sorbet cannot resolve statically.
          end
        end
      RUBY

      expect_no_corrections
    end
  end

  context "when described_class is not used as a constant scope" do
    it "ignores a bare described_class method call" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Payments::Processor do
          subject { described_class.new }
        end
      RUBY
    end

    it "ignores a fully-qualified constant" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Payments::Processor do
          it "uses a fully qualified const" do
            expect(Payments::Processor::Worker).to be_truthy
          end
        end
      RUBY
    end

    it "ignores described_class called on an explicit receiver" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe Payments::Processor do
          it "calls described_class on another object" do
            expect(helper.described_class::Foo).to be_nil
          end
        end
      RUBY
    end
  end
end
