# frozen_string_literal: true

# These specs cover the `MoveNode` sig-awareness patch by exercising
# `RSpec/LetBeforeExamples`, which relocates `let` declarations via
# `RuboCop::RSpec::Corrector::MoveNode#move_before`.
RSpec.describe RuboCop::Cop::RSpec::LetBeforeExamples, :config do
  it "moves a `sig`-typed let above the first example" do
    expect_offense(<<~RUBY)
      describe User do
        let(:a) { 1 }

        it { expect(a).to eq(1) }

        sig { returns(Integer) }
        let(:b) { 2 }
        ^^^^^^^^^^^^^ Move `let` before the examples in the group.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        let(:a) { 1 }

        sig { returns(Integer) }
        let(:b) { 2 }
        it { expect(a).to eq(1) }

      end
    RUBY
  end
end
