# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::PreferProcessLastStatus, :config do
  context "with other global variables" do
    it "does not mark an offense" do
      expect_no_offenses(<<~RUBY)
        my_thing = $LAST_READ_LINE
      RUBY
    end
  end

  context "with $?" do
    it "marks an offense" do
      expect_offense(<<~RUBY)
        return $?.success?
               ^^ Prefer using `Process.last_status` instead of the global variables: `$?` and `$CHILD_STATUS`.
      RUBY
    end

    it "auto-corrects $? to Process.last_status" do
      new_source = autocorrect_source("$?")
      expect(new_source).to eq("Process.last_status")
    end
  end

  context "with $CHILD_STATUS" do
    it "marks an offense" do
      expect_offense(<<~RUBY)
        return $CHILD_STATUS.success?
               ^^^^^^^^^^^^^ Prefer using `Process.last_status` instead of the global variables: `$?` and `$CHILD_STATUS`.
      RUBY
    end

    it "auto-corrects $CHILD_STATUS to Process.last_status" do
      new_source = autocorrect_source("$CHILD_STATUS")
      expect(new_source).to eq("Process.last_status")
    end
  end
end
