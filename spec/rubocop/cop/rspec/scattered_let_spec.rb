# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::ScatteredLet, :config do
  it "flags `let` after the first different node" do
    expect_offense(<<~RUBY)
      RSpec.describe User do
        let(:a) { a }
        it { expect(subject.foo).to eq(a) }
        let(:b) { b }
        ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe User do
        let(:a) { a }
        let(:b) { b }
        it { expect(subject.foo).to eq(a) }
      end
    RUBY
  end

  it "works with heredocs" do
    expect_offense(<<~RUBY)
      describe User do
        let(:a) { <<-BAR }
          hello
          world
        BAR
        it { expect(subject.foo).to eq(a) }
        let(:b) { <<-BAZ }
        ^^^^^^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
          again
        BAZ
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        let(:a) { <<-BAR }
          hello
          world
        BAR
        let(:b) { <<-BAZ }
          again
        BAZ
        it { expect(subject.foo).to eq(a) }
      end
    RUBY
  end

  it "works with comments" do
    expect_offense(<<~RUBY)
      RSpec.describe User do
        let(:a) { a } # a comment
        # example comment
        it { expect(subject.foo).to eq(a) }
        it { expect(subject.fu).to eq(b) } # inline example comment
        # define the second letter
        # with a multi-line description
        let(:b) { b } # inline explanation as well
        ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
      end
    RUBY

    expect_correction(<<~RUBY)
      RSpec.describe User do
        let(:a) { a } # a comment
        # define the second letter
        # with a multi-line description
        let(:b) { b } # inline explanation as well
        # example comment
        it { expect(subject.foo).to eq(a) }
        it { expect(subject.fu).to eq(b) } # inline example comment
      end
    RUBY
  end

  it "flags `let` at different nesting levels" do
    expect_offense(<<~RUBY)
      describe User do
        let(:a) { a }
        it { expect(subject.foo).to eq(a) }

        describe '#property' do
          let(:c) { c }

          it { expect(subject.property).to eq c }

          let(:d) { d }
          ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        let(:a) { a }
        it { expect(subject.foo).to eq(a) }

        describe '#property' do
          let(:c) { c }
          let(:d) { d }

          it { expect(subject.property).to eq c }

        end
      end
    RUBY
  end

  it "doesnt flag `let!` in the middle of multiple `let`s" do
    expect_no_offenses(<<~RUBY)
      describe User do
        subject { User }

        let(:a) { a }
        let!(:b) { b }
        let(:c) { c }
      end
    RUBY
  end

  it "flags scattered `let!`s" do
    expect_offense(<<~RUBY)
      describe User do
        let!(:a) { a }
        it { expect(subject.foo).to eq(a) }
        let!(:c) { c }
        ^^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        let!(:a) { a }
        let!(:c) { c }
        it { expect(subject.foo).to eq(a) }
      end
    RUBY
  end

  it "flags `let` with proc argument" do
    expect_offense(<<~RUBY)
      describe User do
        let(:a) { a }
        it { expect(subject.foo).to eq(a) }
        let(:user, &args[:build_user])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        let(:a) { a }
        let(:user, &args[:build_user])
        it { expect(subject.foo).to eq(a) }
      end
    RUBY
  end

  it "preserves the order of `let`s" do
    expect_offense(<<~RUBY)
      describe User do
        let(:a) { a }
        let(:b) { b }
        it { expect(subject.foo).to eq(a) }
        let(:c) { c }
        ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
        let(:d) { d }
        ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
        it { expect(subject.bar).to eq(d) }
        let(:e) { e }
        ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        let(:a) { a }
        let(:b) { b }
        let(:c) { c }
        let(:d) { d }
        let(:e) { e }
        it { expect(subject.foo).to eq(a) }
        it { expect(subject.bar).to eq(d) }
      end
    RUBY
  end

  it "does not flag an example group with no `let`s" do
    expect_no_offenses(<<~RUBY)
      describe User do
        it { expect(subject.foo).to eq(:bar) }
        it { expect(subject.baz).to eq(:qux) }
      end
    RUBY
  end

  context "with sorbet `sig` declarations attached to `let`s" do
    it "does not flag `sig` declarations between consecutive `let`s" do
      expect_no_offenses(<<~RUBY)
        describe User do
          sig { returns(Something) }
          let(:thing) { create(:something) }

          sig { returns(Other) }
          let(:other) { create(:other) }
        end
      RUBY
    end

    it "does not flag a `sig` before the first `let`" do
      expect_no_offenses(<<~RUBY)
        describe User do
          sig { returns(Something) }
          let(:thing) { create(:something) }
          let(:other) { create(:other) }
        end
      RUBY
    end

    it "does not flag a `sig` between `let`s without a blank line" do
      expect_no_offenses(<<~RUBY)
        describe User do
          let(:a) { a }
          sig { returns(B) }
          let(:b) { b }
        end
      RUBY
    end

    it "flags a scattered `sig`+`let` pair and moves both" do
      expect_offense(<<~RUBY)
        describe User do
          let(:a) { a }
          it { expect(subject.foo).to eq(a) }
          sig { returns(B) }
          let(:b) { b }
          ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
        end
      RUBY

      expect_correction(<<~RUBY)
        describe User do
          let(:a) { a }
          sig { returns(B) }
          let(:b) { b }
          it { expect(subject.foo).to eq(a) }
        end
      RUBY
    end

    it "moves a scattered `let` whose preceding sibling is not its `sig`" do
      expect_offense(<<~RUBY)
        describe User do
          let(:a) { a }
          sig { returns(Integer) }
          def helper
            42
          end
          let(:b) { b }
          ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
        end
      RUBY

      expect_correction(<<~RUBY)
        describe User do
          let(:a) { a }
          let(:b) { b }
          sig { returns(Integer) }
          def helper
            42
          end
        end
      RUBY
    end

    it "flags multiple scattered `sig`+`let` pairs and keeps each pair intact" do
      expect_offense(<<~RUBY)
        describe User do
          sig { returns(A) }
          let(:a) { a }
          it { expect(subject.foo).to eq(a) }
          sig { returns(B) }
          let(:b) { b }
          ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
          sig { returns(C) }
          let(:c) { c }
          ^^^^^^^^^^^^^ Group all let/let! blocks in the example group together.
        end
      RUBY

      expect_correction(<<~RUBY)
        describe User do
          sig { returns(A) }
          let(:a) { a }
          sig { returns(B) }
          let(:b) { b }
          sig { returns(C) }
          let(:c) { c }
          it { expect(subject.foo).to eq(a) }
        end
      RUBY
    end
  end
end
