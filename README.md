# RuboCop::Gusto

[![Gem Version](https://img.shields.io/gem/v/rubocop-gusto)](https://rubygems.org/gems/rubocop-gusto)
[![Build](https://img.shields.io/github/actions/workflow/status/Gusto/rubocop-gusto/build.yml?branch=main)](https://github.com/Gusto/rubocop-gusto/actions/workflows/build.yml)
[![GitHub Release](https://img.shields.io/github/v/release/Gusto/rubocop-gusto)](https://github.com/Gusto/rubocop-gusto/releases)

Gusto's custom [RuboCop](https://rubocop.org/) cops and shared configuration, distributed as a gem and integrated via the [`lint_roller`](https://github.com/standardrb/lint_roller) plugin interface.

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

`rubocop-gusto` ships with a CLI that sets up your project's `.rubocop.yml`:

```sh
bundle exec rubocop-gusto init
```

This adds `rubocop-gusto` to your `.rubocop.yml` `plugins:` list and includes any relevant configuration (e.g. Rails-specific rules when Rails is detected).

If this is an existing project, it is recommended to run the autocorrector (`bundle exec rubocop -a`) and then to regenerate the `.rubocop_todo.yml` (`bundle exec rubocop --auto-gen-config`), so issues can be dealt with piecemeal.

### Available cops

Custom cops live under the following namespaces:

- `Gusto/` — general Gusto-specific cops (see [`lib/rubocop/cop/gusto/`](lib/rubocop/cop/gusto/))
- `Rack/` — cops scoped to Rack middleware patterns (see [`lib/rubocop/cop/rack/`](lib/rubocop/cop/rack/))

## Publishing New Versions

Releases are fully automated via [release-please](https://github.com/googleapis/release-please).

**How it works:**

1. Merge PRs to `main` using [Conventional Commits](https://www.conventionalcommits.org/) in the PR title (enforced by CI).
2. release-please automatically creates and maintains a "Release PR" that bumps the version and updates the changelog.
3. When you merge the Release PR, a GitHub Release and git tag are created, and the gem is published to RubyGems.

**Conventional commit types and version bumps:**

| PR title prefix | Version bump | Example |
|---|---|---|
| `feat:` | Minor (10.8.0 -> 10.9.0) | `feat: add Gusto/NewCop cop` |
| `fix:` | Patch (10.8.0 -> 10.8.1) | `fix: correct false positive in DefaultScope` |
| `feat!:` or `BREAKING CHANGE` footer | Major (10.8.0 -> 11.0.0) | `feat!: drop Ruby 3.1 support` |
| `chore:`, `docs:`, `ci:`, etc. | No release | `chore: update dev dependencies` |

## Contributing

Submit new rules, updated configuration, and other checks to be used organization wide by submitting a Pull Request!

PR titles must use [Conventional Commits](https://www.conventionalcommits.org/) format (enforced by CI) — see the version bump table above for which prefixes trigger releases.

### Adding a new cop

1. Create `lib/rubocop/cop/gusto/<cop_name>.rb`
2. Add an entry to `config/default.yml`, then sort it:
   ```sh
   bundle exec rubocop-gusto sort config/default.yml
   ```
3. Add a spec in `spec/rubocop/cop/gusto/<cop_name>_spec.rb`
4. Run tests and lint:
   ```sh
   bundle exec rspec
   bundle exec rubocop
   ```

### Versioning policy

rubocop-gusto generally follows semver, with the exception that the only thing that is considered a breaking change is a change in the public API to use rubocop-gusto.

Users can generally expect to need to regenerate their rubocop todo when they make a minor version bump to rubocop-gusto.

### Git pre-commit hooks

```sh
git config core.hooksPath script/githooks
```
