## 10.8.0

- Remove redundant `Rails: Enabled: true` from `config/rails.yml` (already set by rubocop-rails' own defaults)
- Enable `Rails/DefaultScope` cop (disabled by default in rubocop-rails)

## [11.6.0](https://github.com/Gusto/rubocop-gusto/compare/v11.5.0...v11.6.0) (2026-07-22)


### Features

* enable Sorbet/RedundantTLetForLiteral and bump rubocop-sorbet for RedundantTLet cops ([#154](https://github.com/Gusto/rubocop-gusto/issues/154)) ([3098b7e](https://github.com/Gusto/rubocop-gusto/commit/3098b7e413c53831354c4c9e8e5337ab743d2a27))
* enable Sorbet/RedundantTLetForLiteral, bump rubocop-sorbet for RedundantTLet cops ([3098b7e](https://github.com/Gusto/rubocop-gusto/commit/3098b7e413c53831354c4c9e8e5337ab743d2a27))


### Bug Fixes

* remove git dependency from Gusto/UnreferencedLet ([#153](https://github.com/Gusto/rubocop-gusto/issues/153)) ([933f5b0](https://github.com/Gusto/rubocop-gusto/commit/933f5b0ec86b422caf0d6e6d460c468e8c00c408))

## [11.5.0](https://github.com/Gusto/rubocop-gusto/compare/v11.4.0...v11.5.0) (2026-07-14)


### Features

* add Gusto/RedundantSpecHelperRequire cop (ADR 116, with autofix) ([#149](https://github.com/Gusto/rubocop-gusto/issues/149)) ([83c22c9](https://github.com/Gusto/rubocop-gusto/commit/83c22c9ee4fb0bc8a5faff11769570009892cccd))

## [11.4.0](https://github.com/Gusto/rubocop-gusto/compare/v11.3.0...v11.4.0) (2026-07-13)


### Features

* add Gusto/ConstantSafety cop ([#148](https://github.com/Gusto/rubocop-gusto/issues/148)) ([7ee7925](https://github.com/Gusto/rubocop-gusto/commit/7ee7925094a7df531d1a9eb078e474fa89b3c133))

## [11.3.0](https://github.com/Gusto/rubocop-gusto/compare/v11.2.0...v11.3.0) (2026-06-29)


### Features

* add Gusto/FeatureFlagConstants cop (RR-890) ([#144](https://github.com/Gusto/rubocop-gusto/issues/144)) ([9058e0e](https://github.com/Gusto/rubocop-gusto/commit/9058e0e3055445a6be1818f2c142013239773bb5))

## [11.2.0](https://github.com/Gusto/rubocop-gusto/compare/v11.1.1...v11.2.0) (2026-06-26)


### Features

* add Gusto/PluckOnSelect cop ([#137](https://github.com/Gusto/rubocop-gusto/issues/137)) ([d87a5cc](https://github.com/Gusto/rubocop-gusto/commit/d87a5ccf45f3f0fca89ed6b6e28cd6f61fc8b023))
* add Gusto/SmartTodoTeam cop enforcing valid team in TODOs (RR-866) ([#143](https://github.com/Gusto/rubocop-gusto/issues/143)) ([8d36bf5](https://github.com/Gusto/rubocop-gusto/commit/8d36bf58983c32d48ff90b3862eb273f543e60a7))
* Ensure rubocop-gusto has access to CodeTeams everywhere it runs (RR-880) ([#141](https://github.com/Gusto/rubocop-gusto/issues/141)) ([b2184ba](https://github.com/Gusto/rubocop-gusto/commit/b2184ba3430359e1210206a09746c979f3826ce3))
* replace Gusto/RailsEnv with upstream Rails/Env ([#106](https://github.com/Gusto/rubocop-gusto/issues/106)) ([7e00033](https://github.com/Gusto/rubocop-gusto/commit/7e0003347dcbed728e4346a7ec2b4f215923a69d))


### Bug Fixes

* use UTF-8 encoding when reading support files in UnreferencedLet ([#136](https://github.com/Gusto/rubocop-gusto/issues/136)) ([651dd25](https://github.com/Gusto/rubocop-gusto/commit/651dd252843a5cfd81dc72bab0abc4b57143c138))

## [11.1.1](https://github.com/Gusto/rubocop-gusto/compare/v11.1.0...v11.1.1) (2026-06-18)


### Bug Fixes

* update ExecuteMigration cop to recommend backfill sidekiq job ([#121](https://github.com/Gusto/rubocop-gusto/issues/121)) ([a29cfcc](https://github.com/Gusto/rubocop-gusto/commit/a29cfcc121fb78b290314500f79ca3150479fa0a))

## [11.1.0](https://github.com/Gusto/rubocop-gusto/compare/v11.0.0...v11.1.0) (2026-06-17)


### Features

* add `Sidekiq/PerformAsyncStub` in a separate config ([#131](https://github.com/Gusto/rubocop-gusto/issues/131)) ([22670d4](https://github.com/Gusto/rubocop-gusto/commit/22670d4a34487417bdb50b8be25e82fb0cac3614))
* add cops-only entrypoints for selective adoption ([#132](https://github.com/Gusto/rubocop-gusto/issues/132)) ([f0911c2](https://github.com/Gusto/rubocop-gusto/commit/f0911c2f9fc6d272bc8ccb5af830daf659c6ba62))

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
