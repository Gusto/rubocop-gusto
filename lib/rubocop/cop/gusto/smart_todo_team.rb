# frozen_string_literal: true

require "smart_todo_cop" # defines RuboCop::Cop::SmartTodo::SmartTodoCop (also requires "smart_todo")
require "code_teams"

module RuboCop
  module Cop
    module Gusto
      # Enforces SmartTodo syntax (via the upstream `SmartTodo/SmartTodoCop`) and,
      # in addition, requires every TODO's `to:` assignee to name a valid team as
      # defined by CodeTeams (`config/teams/**/*.yml`).
      #
      # All of the upstream cop's failure modes are preserved verbatim via `super`.
      # The only additional offense is raised when an otherwise-valid SmartTodo
      # comment is assigned to an unknown team.
      #
      # @example
      #   # bad - assigned to an unknown team
      #   # TODO(on: date('2025-01-01'), to: 'NotATeam')
      #   #   Remove this
      #
      #   # good - assigned to a team in config/teams
      #   # TODO(on: date('2025-01-01'), to: 'Payroll')
      #   #   Remove this
      class SmartTodoTeam < ::RuboCop::Cop::SmartTodo::SmartTodoCop
        TEAM_HELP = "TODO `to:` must name a valid team (see config/teams).  Match the human readable `name:` key (ex: 'Benefits Admin Transfers'), *not* a sluggified form."

        # @param processed_source [RuboCop::ProcessedSource]
        # @return [void]
        def on_new_investigation
          # Registers every existing SmartTodo offense. RuboCop dedupes offenses by
          # source range (see Cop::Base#add_offense), so any comment flagged here
          # silently swallows the duplicate team offense we might add below.
          super

          processed_source.comments.each do |comment|
            next unless TODO_PATTERN.match?(comment.text)

            # `is_a?(String)` guards CodeTeams.find's Sorbet signature, which raises on a
            # non-string. Such assignees are already flagged by `super` (invalid assignee).
            unknown = metadata(comment.text).assignees.select { |assignee| assignee.is_a?(String) && !CodeTeams.find(assignee) }
            next if unknown.empty?

            add_offense(comment, message: "Unknown team(s): #{unknown.join(', ')}. #{TEAM_HELP}")
          end
        end
      end
    end
  end
end
