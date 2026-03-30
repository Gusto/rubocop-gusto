# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Checks for calls to `execute` inside database migrations. Running
      # arbitrary SQL via `execute` is risky: it bypasses ActiveRecord
      # validations and callbacks, can cause long-running table locks on
      # large datasets, and is difficult to roll back safely. Use
      # `add_column`/`change_column` with appropriate options instead, or
      # move data backfills into a separate rake task.
      #
      # @example
      #   # bad
      #   class BackfillUserStatus < ActiveRecord::Migration[7.0]
      #     def change
      #       execute("UPDATE users SET status = 'active' WHERE status IS NULL")
      #     end
      #   end
      #
      #   # good — use a column default for schema changes
      #   class AddStatusToUsers < ActiveRecord::Migration[7.0]
      #     def change
      #       add_column :users, :status, :string, default: 'active', null: false
      #     end
      #   end
      #
      #   # good — move data changes to a backfill rake task
      #   # lib/tasks/backfill_user_status.rake
      #   task backfill_user_status: :environment do
      #     User.where(status: nil).update_all(status: 'active')
      #   end
      #
      class ExecuteMigration < Base
        MSG = "Do not use `execute` to run raw SQL in a migration. " \
              "Run the query from a backfill rake task or pass the SQL options to the " \
              "`add_column`/`change_column` method."
        RESTRICT_ON_SEND = [:execute].freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
