# frozen_string_literal: true

# These specs cover the `MoveNode` sig-awareness patch by exercising
# `RSpec/HooksBeforeExamples`, which relocates hook blocks via
# `RuboCop::RSpec::Corrector::MoveNode#move_before`.
RSpec.describe RuboCop::Cop::RSpec::HooksBeforeExamples, :config do
  it "moves a `sig`-typed hook above the first example" do
    expect_offense(<<~RUBY)
      describe User do
        it { expect(thing).to be }

        sig { void }
        before { prepare }
        ^^^^^^^^^^^^^^^^^^ Move `before` above the examples in the group.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        sig { void }
        before { prepare }
        it { expect(thing).to be }

      end
    RUBY
  end
end
