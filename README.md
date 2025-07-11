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

To publish a new release:

1. Update the `RuboCop::Gusto::VERSION` constant to a higher version number conforming to this project's [versioning policy](#versioning-policy).
2. Document your changes in the [changelog](CHANGELOG.md).
3. Open a pull request and follow the typical review/merge process.
4. TODO: finish release process

After publishing, wait for dependabot, or make a new PR downstream to update to the latest version.

## Contributing

Submit new rules, updated configuration, and other checks to be used organization wide by submitting a Pull Request!

### Versioning policy

Rubocop-gusto generally follows semver, with the exception that the only thing that is considered a breaking change is a change in the public API to use rubocop-gusto.  

Users can generally expect to need to regenerate their rubocop todo when they make a minor version bump to rubocop-gusto.

### Git Pre-Commit Hooks
```
git config core.hooksPath script/githooks
```
