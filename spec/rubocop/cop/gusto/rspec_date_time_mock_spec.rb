# typed: false
# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::RspecDateTimeMock, :config do
  it "registers an offense when using `DateTime.stub`" do
    expect_offense(<<~RUBY)
      allow(DateTime).to receive(:now).and_return(DateTime.new(2020, 1, 1))
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Don't mock Date/Time/DateTime directly. Use Rails Testing Time Helpers (eg `freeze_time` and `travel_to`) instead.
    RUBY
  end

  it "registers an offense when using `DateTime.should_receive`" do
    expect_offense(<<~RUBY)
      expect(DateTime).to receive(:now).and_return(DateTime.new(2020, 1, 1))
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Don't mock Date/Time/DateTime directly. Use Rails Testing Time Helpers (eg `freeze_time` and `travel_to`) instead.
    RUBY
  end

  it "does not register an offense when using `ActiveSupport::Testing::TimeHelpers`" do
    expect_no_offenses(<<~RUBY)
      travel_to DateTime.new(2020, 1, 1) do
        # some code
      end
    RUBY
  end

  it "does not register an offense when allowing Time.parse but calling original implementation" do
    expect_no_offenses(<<~RUBY)
      allow(Time).to receive(:parse).and_call_original
    RUBY
  end

  it "registers an offense when stubbing Time.zone.now" do
    expect_offense(<<~RUBY)
      allow(Time.zone).to receive(:now).and_return(Time.now)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Don't mock Date/Time/DateTime directly. Use Rails Testing Time Helpers (eg `freeze_time` and `travel_to`) instead.
    RUBY
  end

  it "registers an offense when stubbing with receive_message_chain on Time" do
    expect_offense(<<~RUBY)
      allow(Time).to receive_message_chain(:zone, :now).and_return(Time.now)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Don't mock Date/Time/DateTime directly. Use Rails Testing Time Helpers (eg `freeze_time` and `travel_to`) instead.
    RUBY
  end

  describe "helper coverage" do
    let(:cop) { described_class.new }

    def node_for(code)
      RuboCop::ProcessedSource.new(code, 3.2).ast
    end

    it "rooted_in_time_class? returns false for nil" do
      expect(cop.__send__(:rooted_in_time_class?, nil)).to be(false)
    end

    it "rooted_in_time_class? returns false for non-time const" do
      expect(cop.__send__(:rooted_in_time_class?, node_for("String"))).to be(false)
    end

    it "rooted_in_time_class? returns true for Time const" do
      expect(cop.__send__(:rooted_in_time_class?, node_for("Time"))).to be(true)
    end

    it "rooted_in_time_class? returns true for Time.zone chain" do
      expect(cop.__send__(:rooted_in_time_class?, node_for("Time.zone"))).to be(true)
    end

    it "rooted_in_time_class? returns true for Time.now" do
      expect(cop.__send__(:rooted_in_time_class?, node_for("Time.now"))).to be(true)
    end

    it "rooted_in_time_class? returns false when root is not a const (e.g., foo.bar)" do
      expect(cop.__send__(:rooted_in_time_class?, node_for("foo.bar"))).to be(false)
    end

    it "rooted_in_time_class? returns false when traversing to non-const node" do
      # This creates a case where we traverse a method chain but end up at a non-const node
      expect(cop.__send__(:rooted_in_time_class?, node_for("variable.method_call"))).to be(false)
    end

    it "rooted_in_time_class? returns false when root is self" do
      # This hits the branch where current is not const_type (self node)
      expect(cop.__send__(:rooted_in_time_class?, node_for("self.method"))).to be(false)
    end

    it "and_call_original_in_chain? returns false for non-send" do
      expect(cop.__send__(:and_call_original_in_chain?, node_for("Time"))).to be(false)
    end

    it "and_call_original_in_chain? returns false for nil" do
      expect(cop.__send__(:and_call_original_in_chain?, nil)).to be(false)
    end

    it "and_call_original_in_chain? returns true when method is and_call_original" do
      expect(cop.__send__(:and_call_original_in_chain?, node_for("obj.and_call_original"))).to be(true)
    end

    it "and_call_original_in_chain? returns true when chain contains and_call_original" do
      expect(cop.__send__(:and_call_original_in_chain?, node_for("obj.foo.bar.and_call_original"))).to be(true)
    end
  end
end
