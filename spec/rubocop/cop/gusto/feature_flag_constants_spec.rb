# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::FeatureFlagConstants, :config do
  context "when FeatureFlag.active? is called with a string argument" do
    it "registers an offense for double-quoted strings" do
      expect_offense(<<~RUBY)
        FeatureFlag.active?("some_feature_flag")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ FeatureFlag keys should be constants, not strings
      RUBY
    end

    it "registers an offense for single-quoted strings" do
      expect_offense(<<~RUBY)
        FeatureFlag.active?('some_feature_flag')
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ FeatureFlag keys should be constants, not strings
      RUBY
    end

    it "registers an offense when nested in conditions" do
      expect_offense(<<~RUBY)
        if FeatureFlag.active?("nested_feature")
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ FeatureFlag keys should be constants, not strings
          do_something
        end
      RUBY
    end

    it "registers an offense when used in a ternary" do
      expect_offense(<<~RUBY)
        result = FeatureFlag.active?("ternary_feature") ? true : false
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ FeatureFlag keys should be constants, not strings
      RUBY
    end
  end

  context "when FeatureFlag.active? is called with a constant" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        FeatureFlag.active?(MY_FEATURE_FLAG_CONSTANT)
      RUBY
    end

    it "does not register an offense for namespaced constants" do
      expect_no_offenses(<<~RUBY)
        FeatureFlag.active?(MyModule::MY_CONSTANT)
      RUBY
    end
  end

  context "when FeatureFlag.active? is called with a variable" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        feature_key = "some_feature"
        FeatureFlag.active?(feature_key)
      RUBY
    end
  end

  context "when active? is called on a different receiver" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        SomethingElse.active?("some_feature_flag")
      RUBY
    end

    it "does not register an offense for a bare active? call" do
      expect_no_offenses(<<~RUBY)
        active?("some_feature_flag")
      RUBY
    end
  end

  context "when FeatureFlag is used with a different method" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        FeatureFlag.enabled?("some_feature_flag")
      RUBY
    end
  end
end
