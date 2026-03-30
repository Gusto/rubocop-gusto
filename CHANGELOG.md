## 10.8.0

- Remove redundant `Rails: Enabled: true` from `config/rails.yml` (already set by rubocop-rails' own defaults)
- Enable `Rails/DefaultScope` cop (disabled by default in rubocop-rails)

## [10.8.1](https://github.com/Gusto/rubocop-gusto/compare/v10.8.0...v10.8.1) (2026-03-30)


### Bug Fixes

* Change runner configuration to use custom group ([#95](https://github.com/Gusto/rubocop-gusto/issues/95)) ([87af85d](https://github.com/Gusto/rubocop-gusto/commit/87af85d17c150d689ca73448e0d2b5372968f21b))
* correct release-please-action pinned SHA ([#89](https://github.com/Gusto/rubocop-gusto/issues/89)) ([87db13a](https://github.com/Gusto/rubocop-gusto/commit/87db13ad17f60d0398a84dc7957515cac623efee))
* pin GitHub Actions to commit SHAs to prevent supply-chain attacks ([#85](https://github.com/Gusto/rubocop-gusto/issues/85)) ([bc85834](https://github.com/Gusto/rubocop-gusto/commit/bc85834d5fbed70278f9cd67eff6e564fb4e9925))
* remove extra empty line at block body end in execute_migration_spec ([87af85d](https://github.com/Gusto/rubocop-gusto/commit/87af85d17c150d689ca73448e0d2b5372968f21b))
* use GitHub App token in release-please to trigger CI on PRs ([#98](https://github.com/Gusto/rubocop-gusto/issues/98)) ([a2d3171](https://github.com/Gusto/rubocop-gusto/commit/a2d3171909ee8fe04be233b13adb8aaac48e0bef))

## 10.7.0

- Improve `Rack/LowercaseHeaderKeys` for Rack 3 migration
- Change `Style/StringLiterals` `EnforcedStyle` from `always` to `always_true`

## 10.6.0

- Add `Rack/LowercaseHeaderKeys` cop to detect and autocorrect uppercase HTTP response header keys
- Enable Style/StringLiterals with double quotes enforced

## 10.5.0

- Delete Object#in? cop

## 10.4.0

- Add Gusto/DiscouragedGem cop with `timecop` as the first discouraged gem
- Update Gusto/PolymorphicTypeValidation settings to be scoped to `**/models/*.rb`

## 10.3.0

- Add Gusto/RspecDateTimeMock cop

## 10.2.0

- Fix Sorbet sigil exclusions, exclude specs from strict, and add rubocop-sorbet dependency
- Add ActiveSupportExtensionsEnabled to rails config
- Fix infinite loop and splitting problem in init command
- Use default Style/InverseMethods configuration

## 10.1.1

- Opt in to Rails/IgnoredColumnsAssignment
- Revert "Add Gusto/IgnoredColumnAssignment"
- Update rubocop dependency from 1.79.0 to 1.79.1

## 10.1.0

- Add Gusto/IgnoredColumnAssignment cop

## 10.0.1

- Require rubocop >= 1.76 to ensure Naming/PredicatePrefix is available.

## 10.0.0
- First open source release of style template, tools, and custom rules
