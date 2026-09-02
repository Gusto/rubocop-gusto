# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::TypeVariables, :config do
  it "registers an offense when type_member is untyped" do
    expect_offense(<<~RUBY)
      type_member { { fixed: T.untyped } }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `type_member` and `type_template` in GraphQL objects must not be untyped. The type here should match the type expected from the `object` method.
    RUBY
  end

  it "registers an offense when type_template is untyped" do
    expect_offense(<<~RUBY)
      type_template { { fixed: T.untyped } }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `type_member` and `type_template` in GraphQL objects must not be untyped. The type here should match the type expected from the `object` method.
    RUBY
  end

  it "does not register an offense when type_member is typed" do
    expect_no_offenses(<<~RUBY)
      type_member { { fixed: T.anything_else } }
    RUBY
  end

  it "does not register an offense when type_template is typed" do
    expect_no_offenses(<<~RUBY)
      type_template { { fixed: T.anything_else } }
    RUBY
  end
end
