# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::RablExtends, :config do
  it "does not register an offense for unrelated code" do
    expect_no_offenses(<<~RUBY, "renderer.rabl")
      extends SomeClass
      some_method_with_extends_in_it
    RUBY
  end

  it "registers an offense when using extends" do
    expect_offense(<<~RUBY, "renderer.rabl")
      extends 'path/to/template'
      ^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using Rabl extends as it has poor caching performance.[...]
    RUBY
  end

  it "registers no offense outside a rabl file" do
    expect_no_offenses(<<~RUBY)
      extends 'path/to/template'
    RUBY
  end

  it "registers an offense when using extends with multiple arguments" do
    expect_offense(<<~RUBY, "renderer.rabl")
      extends 'path/to/template', locals: { foo: 'bar' }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid using Rabl extends as it has poor caching performance.[...]
    RUBY
  end

  it "does not register an offense when using partial" do
    expect_no_offenses(<<~RUBY, "renderer.rabl")
      partial 'path/to/template'
    RUBY
  end

  it "does not register an offense for other method calls" do
    expect_no_offenses(<<~RUBY, "renderer.rabl")
      node 'some_node'
      attributes :foo, :bar
      child(:baz) { attributes :qux }
    RUBY
  end
end
