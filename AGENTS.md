# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

`rubocop-gusto` is a RubyGem that ships Gusto's custom RuboCop cops and a shared RuboCop configuration. It integrates via the `lint_roller` plugin interface, so consuming projects add it to their `plugins:` list in `.rubocop.yml`.

## Commands

```sh
# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/rubocop/cop/gusto/some_cop_spec.rb

# Run a single example by line number
bundle exec rspec spec/rubocop/cop/gusto/some_cop_spec.rb:42

# Sort cops in a rubocop yml file (required after adding a new cop entry to config/default.yml)
bundle exec rubocop-gusto sort config/default.yml

# Initialize rubocop-gusto in a consuming project
bundle exec rubocop-gusto init
```

## Project structure

- `lib/rubocop/cop/gusto/` — Custom Gusto cops (one file per cop)
- `lib/rubocop/cop/rack/` — Custom cops scoped to Rack middleware patterns
- `lib/rubocop/cop/internal_affairs/` — Cops that lint *this gem's own cops* (enforced in CI on this repo)
- `lib/rubocop/gusto/` — Supporting library code: `CLI`, `Init`, `ConfigYml`, `Plugin`, `version`
- `config/default.yml` — The shared RuboCop configuration distributed with this gem
- `config/rails.yml` — Additional Rails-specific configuration (included by `init` when Rails is detected)
- `spec/rubocop/cop/` — Mirrored spec structure matching `lib/rubocop/cop/`

## Writing a new cop

1. Create `lib/rubocop/cop/gusto/<cop_name>.rb` with class `RuboCop::Cop::Gusto::<CopName> < Base`.
2. If the cop uses `on_send` or `after_send`, declare `RESTRICT_ON_SEND = %i(...).freeze` — the `InternalAffairs::RequireRestrictOnSend` cop enforces this.
3. Use `def_node_matcher` / `def_node_search` with `# @!method` YARD annotations for all AST pattern matchers.
4. Add an entry to `config/default.yml` with at minimum a `Description:` key, then run `bundle exec rubocop-gusto sort config/default.yml`.
5. Create a corresponding spec in `spec/rubocop/cop/gusto/<cop_name>_spec.rb`.

## Writing cop specs

Specs use `RuboCop::RSpec::ExpectOffense` helpers (included globally via `spec_helper.rb`):

```ruby
RSpec.describe RuboCop::Cop::Gusto::MyCop, :config do
  it "registers an offense" do
    expect_offense(<<~RUBY)
      bad_method_call
      ^^^^^^^^^^^^^^^ MyCop message here
    RUBY
  end

  it "does not register an offense" do
    expect_no_offenses(<<~RUBY)
      good_method_call
    RUBY
  end
end
```

The `:config` metadata provides a default `RuboCop::Config` instance. Pass cop-specific config by constructing `RuboCop::Config.new(...)` directly.

## ConfigYml utility

`RuboCop::Gusto::ConfigYml` reads and writes `.rubocop.yml` while preserving comments. It parses the file into "preamble" blocks (e.g. `inherit_gem`, `plugins`) and "cops" blocks, and can sort, add plugins, or add `inherit_gem` entries without clobbering existing content.

## Git hooks

Run once after cloning to enable the pre-commit hook:

```sh
git config core.hooksPath script/githooks
```
