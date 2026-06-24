# frozen_string_literal: true

require "code_teams/testing"

# Installs CodeTeams::Testing's RSpec helpers (`code_team_with_config`) and the
# per-example cache reset. Idempotent.
CodeTeams::Testing.enable!

RSpec.describe(RuboCop::Cop::Gusto::SmartTodoTeam, :config) do
  before { code_team_with_config(name: "Payroll") }

  it("does not register an offense when the TODO targets a valid team") do
    expect_no_offenses(<<~RUBY)
      # TODO(on: date('2025-01-01'), to: 'Payroll')
      x = 1
    RUBY
  end

  it("registers an offense when the TODO targets an unknown team") do
    expect_offense(<<~RUBY)
      # TODO(on: date('2025-01-01'), to: 'NotATeam')
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Unknown team(s): NotATeam. TODO `to:` must name a valid team (see config/teams).  Match the human readable `name:` key (ex: 'Benefits Admin Transfers'), *not* a sluggified form.
    RUBY
  end

  it("does not register a team offense for non-TODO comments") do
    expect_no_offenses(<<~RUBY)
      # just a regular comment, not a TODO
      x = 1
    RUBY
  end

  # Inherited SmartTodo failure modes still fire via `super`. A non-string assignee
  # is flagged by the upstream cop; our team check skips it (is_a?(String) is false),
  # so there is exactly one offense (the upstream one), not a duplicate.
  it("preserves the upstream offense for a non-string assignee") do
    expect_offense(<<~RUBY)
      # TODO(on: date('2025-01-01'), to: 123)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Invalid event assignee. This method only accepts strings. For more info please look at https://github.com/Shopify/smart_todo/wiki/Syntax
    RUBY
  end

  # A lowercase tag is flagged by the upstream cop. Even though the team is unknown,
  # RuboCop dedupes by range, so only the upstream offense is reported (added first).
  it("preserves the upstream offense for a lowercase tag and does not double-report") do
    expect_offense(<<~RUBY)
      # todo(on: date('2025-01-01'), to: 'NotATeam')
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Don't write regular TODO comments. Write SmartTodo compatible syntax comments. For more info please look at https://github.com/Shopify/smart_todo/wiki/Syntax
    RUBY
  end
end
