# Rubocop::Gusto

Gusto's Ruby style guide implemented as RuboCop rules.

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

`rubocop-gusto` ships with an executable that updates and maintains .rubocop.yml.

```sh
bundle exec rubocop-gusto init
```

If this is an existing project, it is recommended to run the autocorrector (`bundle exec rubocop -a`) and then to regenerate the `.rubocop_todo.yml` (`bundle exec rubocop --auto-gen-config`), so issues can be dealt with piecemeal.

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

### Versioning policy

Rubocop-gusto generally follows semver, with the exception that the only thing that is considered a breaking change is a change in the public API to use rubocop-gusto.  

Users can generally expect to need to regenerate their rubocop todo when they make a minor version bump to rubocop-gusto.

### Git Pre-Commit Hooks
```
git config core.hooksPath script/githooks
```
