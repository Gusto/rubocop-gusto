# frozen_string_literal: true

# These specs cover the `MoveNode` sig-awareness patch by exercising
# `RSpec/LeadingSubject`, which relocates `subject` declarations via
# `RuboCop::RSpec::Corrector::MoveNode#move_before`.
RSpec.describe RuboCop::Cop::RSpec::LeadingSubject, :config do
  it "moves a `sig`-typed subject above its offending sibling" do
    expect_offense(<<~RUBY)
      describe User do
        let(:params) { {} }
        sig { returns(User) }
        subject { described_class.new(params) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Declare `subject` above any other `let` declarations.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        sig { returns(User) }
        subject { described_class.new(params) }
        let(:params) { {} }
      end
    RUBY
  end

  it "moves the subject above a `sig`-typed offending sibling" do
    expect_offense(<<~RUBY)
      describe User do
        sig { returns(Hash) }
        let(:params) { {} }
        subject { described_class.new(params) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Declare `subject` above any other `let` declarations.
      end
    RUBY

    expect_correction(<<~RUBY)
      describe User do
        subject { described_class.new(params) }
        sig { returns(Hash) }
        let(:params) { {} }
      end
    RUBY
  end
end
