## Pending

- Enable 12 cops that improve code quality and agentic coding: `Naming/AccessorMethodName`,
  `Rake/ClassDefinitionInTask`, `RSpec/MatchArray`, `RSpec/NotToNot`, `Style/AccessorGrouping`,
  `Style/Documentation`, `Style/EmptyElse`, `Style/HashTransformKeys`, `Style/HashTransformValues`,
  `Style/Next`, `Rails/ActiveRecordAliases`, `Rails/HasManyOrHasOneDependent`, `Rails/NotNullColumn`
- Add explanatory comments to all `Enabled: false` entries in `config/default.yml` and `config/rails.yml`
- Add `Style/Documentation` comments to all cop and CLI classes
- Add `.yamllint.yml` and resolve yamllint violations in `config/` and `lefthook.yml`
- Add yamllint check to lefthook pre-commit and pre-push hooks

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
