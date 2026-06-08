## 10.8.0

- Remove redundant `Rails: Enabled: true` from `config/rails.yml` (already set by rubocop-rails' own defaults)
- Enable `Rails/DefaultScope` cop (disabled by default in rubocop-rails)

## [11.0.0](https://github.com/Gusto/rubocop-gusto/compare/v10.10.0...v11.0.0) (2026-06-08)


### ⚠ BREAKING CHANGES

* rubocop-gusto now requires Ruby >= 3.4.

### Features

* add Gusto/DescribedClassConstantReference cop ([#127](https://github.com/Gusto/rubocop-gusto/issues/127)) ([f7cf636](https://github.com/Gusto/rubocop-gusto/commit/f7cf6362f3f522f322251da0fdf5c8affa35bc0f))
* add Gusto/UnreferencedLet cop (requires Ruby &gt;= 3.4) ([#128](https://github.com/Gusto/rubocop-gusto/issues/128)) ([99a2df7](https://github.com/Gusto/rubocop-gusto/commit/99a2df761b52ce11f4f6bf65a5c8e414153efa53))

## [10.10.0](https://github.com/Gusto/rubocop-gusto/compare/v10.9.4...v10.10.0) (2026-06-01)


### Features

* Set EnforcedShorthandSyntax to 'always' ([#116](https://github.com/Gusto/rubocop-gusto/issues/116)) ([650a8aa](https://github.com/Gusto/rubocop-gusto/commit/650a8aa26ee5af6d7558976dce6df18f053e1925))

## [10.9.4](https://github.com/Gusto/rubocop-gusto/compare/v10.9.3...v10.9.4) (2026-06-01)


### Bug Fixes

* tighten Sorbet sigil config and allow RBS inline annotations ([#120](https://github.com/Gusto/rubocop-gusto/issues/120)) ([0e9eef6](https://github.com/Gusto/rubocop-gusto/commit/0e9eef619b3123fc78004ee8466cf3b4137dd0b8))

## [10.9.3](https://github.com/Gusto/rubocop-gusto/compare/v10.9.2...v10.9.3) (2026-05-27)


### Bug Fixes

* stop overriding AllCops scope in shared configs ([#117](https://github.com/Gusto/rubocop-gusto/issues/117)) ([6e1f5db](https://github.com/Gusto/rubocop-gusto/commit/6e1f5db6b6e12147c2d09f06f6a680c32eba36e7))

## [10.9.2](https://github.com/Gusto/rubocop-gusto/compare/v10.9.1...v10.9.2) (2026-05-22)


### Bug Fixes

* upload gem from pkg/ to GitHub release ([#114](https://github.com/Gusto/rubocop-gusto/issues/114)) ([de0530e](https://github.com/Gusto/rubocop-gusto/commit/de0530e65acfc9a8ab789ea89011e089dda5072e))

## [10.9.1](https://github.com/Gusto/rubocop-gusto/compare/v10.9.0...v10.9.1) (2026-05-22)


### Bug Fixes

* remove redundant config entries ([#112](https://github.com/Gusto/rubocop-gusto/issues/112)) ([e3dab8d](https://github.com/Gusto/rubocop-gusto/commit/e3dab8d3f96907a4b4be955fd3407926aa47b5a7))

## [10.9.0](https://github.com/Gusto/rubocop-gusto/compare/v10.8.1...v10.9.0) (2026-05-22)


### Features

* make rubocop-rspec move/scatter cops Sorbet-sig-aware ([#107](https://github.com/Gusto/rubocop-gusto/issues/107)) ([b3f1449](https://github.com/Gusto/rubocop-gusto/commit/b3f14491b74548adbd05738b90484ba6ccb5ea67))

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
