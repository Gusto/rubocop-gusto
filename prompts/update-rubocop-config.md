# Update RuboCop configuration

Review and update the RuboCop cop configurations in config/default.yml and
config/rails.yml. These configs are for new Ruby services and are intentionally
separate from config/default-legacy.yml and config/rails-legacy.yml, which
cover existing projects and should not be modified.

## Files

- config/default.yml — applies to all Ruby projects
- config/rails.yml  — applies to Rails projects (loaded alongside default.yml)

## Priorities (highest to lowest)

1. Sorbet compatibility. Any cop that produces output incompatible with Sorbet's
   static analysis must be disabled, regardless of other benefits. This is a hard
   constraint. When in doubt, check
   <https://github.com/sorbet/sorbet/issues>.

2. Correctness and safety. Prefer configurations that prevent bugs, data loss,
   or security vulnerabilities over those that are purely stylistic. Lint cops
   that catch real bugs should be elevated to Severity: error.

3. Reviewability and diff quality. Smaller, more focused diffs are preferable.
   Favor cops that reduce the number of ways to write functionally equivalent
   code (e.g. trailing commas on multiline literals, fixed indentation over
   alignment-based indentation).

4. Consistency for coding agents. Agents are the primary authors and readers.
   Favor configurations that result in agents generating similar code across
   similar contexts — consistent indentation, structure, and idiom reduce the
   surface area agents must reason about.

5. Idiomatic modern Ruby. Follow what the Rails project, RuboCop's own style
   guide, and widely-adopted style guides (Standard, Shopify) agree on. Prefer
   modern syntax over legacy alternatives when the ecosystem has converged (e.g.
   symbol-key hashes over hash rockets, `->` lambdas, `alias_method` over
   `alias`). Do not standardize on an older form merely because it reduces
   variation.

6. Performance. Prefer configurations appropriate for high-scale web applications.
   Enable performance cops that eliminate unnecessary allocations or inefficient
   patterns.

The cost of resolving a linter violation is low — most are autocorrectable
before a CI run begins. Do not disable or relax cops to avoid fixing existing
violations.

The cost of an additional CI run, however, is high. In monolith repositories a
single change can select a large test suite, making each failed CI run expensive
in both time and engineering attention. Configurations that prevent agents from
producing code that will fail CI are therefore especially valuable — more so
than configurations that merely enforce style. When choosing between two
otherwise equivalent configurations, prefer the one that makes a class of
runtime or test-time error impossible to introduce in the first place.

For example, `Style/AccessModifierDeclarations: EnforcedStyle: inline` requires
access modifiers to appear on the same line as the method definition
(`private def foo`). This makes it structurally impossible for an agent to
place a public method inside a `private` group — a mistake that compiles and
passes static analysis but causes test failures at runtime when callers outside
the class attempt to invoke the method.

## Process

A complete review considers three dimensions for every cop in every plugin:
whether it is enabled, whether its non-boolean parameters are set correctly, and
whether it has any mode flags (`AllowedMethods`, `AllowedPatterns`,
`CheckForMethodsWithNoSideEffects`, `IncludeActiveSupportAliases`, etc.) that
change what the cop catches. Enabling a cop with poor parameter choices can be
worse than not enabling it at all.

### Step 1 — Read the full default configuration

For each cop in each plugin's `config/default.yml`, extract **all** configurable
keys, not just `Enabled`. Typical parameters to examine:

- `EnforcedStyle` and `SupportedStyles` — which style is the default and whether
  the alternatives are better for Sorbet-typed, high-scale Rails code
- `Max` / `Min` — numeric limits; see the **Setting numeric limits** section
- `CheckFor…` / `Include…` / `Allow…` flags — boolean mode switches that
  expand or restrict what the cop catches (e.g.
  `CheckForMethodsWithNoSideEffects`, `IncludeActiveSupportAliases`,
  `AllowUnusedKeywordArguments`)
- `AllowedMethods` / `AllowedPatterns` — lists that suppress the cop for
  specific call sites; ensure these are not inadvertently too broad
- `Safe` / `SafeAutoCorrect` — whether the autocorrect changes semantics; flag
  any unsafe autocorrects that could silently alter behavior

### Step 2 — Evaluate each parameter against the priorities

For every non-default parameter value that could be set:

1. **Does the default parameter value conflict with Sorbet?** Some parameters
   trigger autocorrects that break Sorbet sigs (e.g. removing a `&blk` param
   that a sig references). Override to preserve Sorbet compatibility.

2. **Does a non-default value catch more real bugs?** Mode flags like
   `CheckForMethodsWithNoSideEffects: true` extend a cop's reach to cover
   additional error classes. If the extended coverage catches genuine mistakes
   without significant false-positive risk, enable it.

3. **Does the parameter affect consistency or diff quality?** Style parameters
   like `EnforcedShorthandSyntax: either_consistent` prevent mixed patterns
   within a single construct, reducing variation without forcing a global choice.

4. **Does the parameter need to account for Rails or ActiveSupport extensions?**
   Several cops have flags like `IncludeActiveSupportAliases` that are `false`
   by default because Active Support is not universally present. In rails.yml,
   enable these flags when the ActiveSupport method is a better candidate for
   enforcement than the stdlib equivalent.

5. **Do not add a parameter entry that matches the default.** Only configure
   parameters that deviate from the upstream default, for the same reason that
   redundant `Enabled: true` entries are omitted.

### Step 3 — Placement, ordering, and comments

1. Verify which file the cop belongs in: default.yml for all Ruby projects,
   rails.yml for Rails-specific cops.

2. Maintain alphabetical ordering within each file.

3. Include a comment for every entry explaining:
   - Why the default was changed, or why a disabled-by-default cop is enabled
   - Why a non-default parameter value was chosen
   - Any relevant links (upstream issues, style guide references, incident reports)
   - **Do not cite the legacy config as a justification.** "Matches the legacy
     config" is not a reason to disable or relax a cop. Every entry must stand
     on its own merits within the priority framework.

## Setting numeric limits

Many cops enforce a numeric ceiling — maximum method length, maximum number of
expectations per example, maximum ABC score, and so on. RuboCop's upstream
defaults for these limits are calibrated for general Ruby programs, not for
high-scale web applications. Production web services routinely involve concerns
that have no analog in the programs rubocop's authors had in mind: network
failure handling, database transaction management, multi-step validation logic,
authentication and authorization layers, serialization across API boundaries,
and background job orchestration. Each of these concerns legitimately adds
lines, branches, and complexity without indicating that code is poorly designed.

When evaluating a numeric limit, do not accept the upstream default uncritically.
Instead, reason about what the limit means for code of this kind:

- **Is the upstream default calibrated for production web services?** If the
  default would flag a large fraction of ordinary, well-written application
  code, it is not functioning as a signal — it is functioning as noise. A limit
  that fires constantly requires agents to burn cycles reorganizing code rather
  than solving the assigned problem.

- **What does a genuine violation look like in this context?** The limit should
  separate code that is incidentally complex (handling real requirements) from
  code that is structurally complex (doing too many things, missing
  abstractions, or resisting decomposition). The former is acceptable; the
  latter is what the cop should catch.

- **Is the limit consistent with what we already accept?** Examine the existing
  entries in config/default.yml for the same category of cop. If the Metrics
  limits are set well above the rubocop defaults to reflect production
  realities, apply the same reasoning to RSpec limits, line-length limits, and
  any other numeric threshold. The calibration philosophy should be uniform.

In practice, limits for high-scale web application code are often materially
higher than rubocop's defaults — sometimes two to five times higher. This is
not a relaxation of quality standards; it is an acknowledgment that the default
was written for a different class of program. The goal is a limit that fires
on code that genuinely needs attention, not on code that is merely longer than
a script or utility gem would be.

## New cops and pending cops

The shared config sets `NewCops: disable` in `AllCops`. This means cops that
are newly added to rubocop or its plugins default to off. The reason is not
to give the team time to evaluate them — that is unlikely to happen organically.
The reason is to allow the broader rubocop community to surface issues, report
false positives, and refine the cop's behavior before we adopt it. Pending cops
are experimental by design; the community feedback loop is how they get
stabilized. Do not change this setting.

Pending cops (those marked `Enabled: pending` in the upstream gem) are
**not** automatically enabled by `NewCops: disable`. During a config review,
consider each pending cop explicitly: read its description, evaluate it against
the priority framework, and add an entry to enable it if it is sufficiently
mature and useful. If you enable a pending cop, note in the comment that it is
pending upstream.

## Stability of existing configuration

Once a cop is configured — enabled, disabled, or given specific parameter
values — that setting should be treated as a deliberate decision. Do not
revisit or overturn existing settings without strong, concrete evidence that
the current setting is wrong. Acceptable reasons to change an existing entry:

- A production incident or CI failure that the new setting would make less
  likely, or that the current setting contributed to.
- A Sorbet compatibility issue newly discovered or newly documented upstream.
- Empirical data (e.g. updated percentile measurements from production
  codebases) that materially changes the numeric calibration.
- A cop's behavior changed in a new gem version in a way that makes the
  existing configuration incorrect.

Arguments based on personal preference, aesthetic disagreement, or "this seems
wrong" without specific evidence do not meet this bar. The cost of changing a
widely-deployed lint standard is borne by every codebase that inherits it. A
reconfiguration that touches dozens of services consumes CI cycles and adds
noise to git history across all of them — churn
that delivers no product value. Stability in the configuration is itself a
value.

## Conflict resolution

When the priorities above conflict in a way that is not clearly resolved by their
ordering — for example, a cop that improves consistency but requires a non-idiomatic
style, or a performance cop whose autocorrect is unsafe — pause and ask for guidance
before proceeding.
