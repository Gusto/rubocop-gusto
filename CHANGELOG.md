## Pending

- Remove redundant `Rails: Enabled: true` from `config/rails.yml` (already set by rubocop-rails' own defaults)
- Enable `Rails/DefaultScope` cop (disabled by default in rubocop-rails)

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
