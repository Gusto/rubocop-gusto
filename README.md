# rubocop-gusto

Gusto's Ruby style guide implemented as RuboCop cops and shared configuration.

## Purpose

This gem is a **north star** for Ruby code quality at Gusto. It encodes best practices as
enforceable rules — not a snapshot of the current state of any given codebase. Coding agents
are expected to be the dominant readers and writers of Ruby code going forward, and consistent,
well-documented style rules give them (and humans) a single authoritative reference for how
Gusto Ruby should look.

Individual repositories adopt these rules incrementally. A new or existing project that can't
yet comply with every rule should generate a `.rubocop_todo.yml` to suppress known violations
and address them over time — not ask this gem to weaken the rules.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rubocop-gusto', require: false
```

And then execute:

```sh
$ bundle
```

## Usage

`rubocop-gusto` ships with an executable that initializes and maintains `.rubocop.yml`.

```sh
bundle exec rubocop-gusto init
```

For existing projects, run the autocorrector and then generate a todo file so violations can be
addressed incrementally:

```sh
bundle exec rubocop -a
bundle exec rubocop --auto-gen-config
```

The todo file suppresses known violations without weakening the shared configuration. As the
codebase improves, entries are removed from the todo file rather than rules being softened here.

## Publishing New Versions

To publish a new release:

1. Update the `RuboCop::Gusto::VERSION` constant to a higher version number conforming to this project's [versioning policy](#versioning-policy).
2. Document your changes in the [changelog](CHANGELOG.md).
3. Open a pull request and follow the typical review/merge process.
4. TODO: finish release process

After publishing, wait for dependabot, or make a new PR downstream to update to the latest version.

## Contributing

Submit new rules, updated configuration, and other checks to be used organization wide by submitting a Pull Request!

When evaluating whether to enable or strengthen a rule, the primary question is: **is this the
right practice?** The number of existing violations in downstream codebases is not a reason to
disable a rule here — it is a reason to generate a todo file and fix violations over time.

### Versioning policy

`rubocop-gusto` generally follows semver, with the exception that the only thing considered a
breaking change is a change to the public API for consuming the gem.

Consumers should expect to regenerate their rubocop todo when making a minor version bump.

### Git Pre-Commit Hooks
```
git config core.hooksPath script/githooks
```
