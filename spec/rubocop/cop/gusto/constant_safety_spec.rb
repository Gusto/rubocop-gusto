# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::ConstantSafety, :config do
  context "when safe navigation is called on a class/module constant" do
    it "registers an offense and autocorrects to plain navigation" do
      expect_offense(<<~RUBY)
        Model&.find(id)
             ^^ Do not use safe navigation (`&.`) on a constant; constants are never `nil`, so use `.` instead.
      RUBY

      expect_correction(<<~RUBY)
        Model.find(id)
      RUBY
    end
  end

  context "when safe navigation is called on a SCREAMING_CASE constant" do
    it "registers an offense and autocorrects to plain navigation" do
      expect_offense(<<~RUBY)
        ENTITY_TYPES&.each { |type| type.to_s }
                    ^^ Do not use safe navigation (`&.`) on a constant; constants are never `nil`, so use `.` instead.
      RUBY

      expect_correction(<<~RUBY)
        ENTITY_TYPES.each { |type| type.to_s }
      RUBY
    end
  end

  context "when safe navigation is called on a namespaced constant" do
    it "registers an offense and autocorrects to plain navigation" do
      expect_offense(<<~RUBY)
        Foo::Bar&.call
                ^^ Do not use safe navigation (`&.`) on a constant; constants are never `nil`, so use `.` instead.
      RUBY

      expect_correction(<<~RUBY)
        Foo::Bar.call
      RUBY
    end
  end

  context "when safe navigation is called on a top-level (cbase) constant" do
    it "registers an offense and autocorrects to plain navigation" do
      expect_offense(<<~RUBY)
        ::Foo&.call
             ^^ Do not use safe navigation (`&.`) on a constant; constants are never `nil`, so use `.` instead.
      RUBY

      expect_correction(<<~RUBY)
        ::Foo.call
      RUBY
    end
  end

  context "when safe navigation is called on a non-constant receiver" do
    it "does not register an offense for a local variable or method call" do
      expect_no_offenses(<<~RUBY)
        foo&.bar
        user.account&.name
      RUBY
    end
  end

  context "when a constant uses plain (non-safe) navigation" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        Model.find(id)
        ENTITY_TYPES.each { |type| type.to_s }
      RUBY
    end
  end
end
