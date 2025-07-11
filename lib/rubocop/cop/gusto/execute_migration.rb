# frozen_string_literal: true

module RuboCop
  module Cop
    module Gusto
      class ExecuteMigration < Base
        MSG = 'Do not use `execute` to run raw SQL in a migration. Run the query from a backfill rake task or pass the SQL options to the `add_column`/`change_column` method.'
        RESTRICT_ON_SEND = [:execute].freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
