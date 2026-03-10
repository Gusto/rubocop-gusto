# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      # Flags use of +execute+ to run raw SQL inside Active Record migrations.
      #
      # Mixing data transformations with schema changes makes rollbacks risky and
      # complicates zero-downtime deployments. Data backfills should live in a separate
      # rake task that can be run independently, retried, or skipped without re-running
      # the migration. For schema-level SQL (e.g., column defaults), prefer the options
      # hash on +add_column+ / +change_column+ instead.
      #
      # @example bad
      #   def up
      #     execute "UPDATE users SET status = 'active' WHERE status IS NULL"
      #   end
      #
      # @example good
      #   # Schema change in the migration, data change in a separate backfill task
      #   def change
      #     add_column :users, :status, :string
      #   end
      class ExecuteMigration < Base
        MSG = "Do not use `execute` to run raw SQL in a migration. Run the query from a backfill rake task or pass the SQL options to the `add_column`/`change_column` method."
        RESTRICT_ON_SEND = [:execute].freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
