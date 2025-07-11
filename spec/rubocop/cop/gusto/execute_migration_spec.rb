# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::ExecuteMigration, :config do
  it('registers an offense when using execute in a migration') do
    expect_offense(<<~RUBY)
      class CreateUsers < ActiveRecord::Migration[6.0]
        def change
          execute("CREATE TABLE users (id int)")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `execute` to run raw SQL in a migration. Run the query from a backfill rake task or pass the SQL options to the `add_column`/`change_column` method.
        end
      end
    RUBY
  end

  it('does not register an offense when using other methods in a migration') do
    expect_no_offenses(<<~RUBY)
      class CreateUsers < ActiveRecord::Migration[6.0]
        def change
          create_table :users do |t|
            t.string :name
            t.timestamps
          end
        end
      end
    RUBY
  end

  it('registers an offense when using execute in an up method') do
    expect_offense(<<~RUBY)
      class AddIndexToUsers < ActiveRecord::Migration[6.0]
        def up
          execute("CREATE INDEX index_users_on_email ON users (email)")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `execute` to run raw SQL in a migration. Run the query from a backfill rake task or pass the SQL options to the `add_column`/`change_column` method.
        end
      end
    RUBY
  end

  it('registers an offense when using execute in a down method') do
    expect_offense(<<~RUBY)
      class AddIndexToUsers < ActiveRecord::Migration[6.0]
        def down
          execute("DROP INDEX index_users_on_email")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use `execute` to run raw SQL in a migration. Run the query from a backfill rake task or pass the SQL options to the `add_column`/`change_column` method.
        end
      end
    RUBY
  end

  it('does not register an offense for execute outside of migrations', pending: 'after fixing Cop to only apply in migration context, enable this spec') do
    expect_no_offenses(<<~RUBY)
      class SomeClass
        def some_method
          execute("SELECT * FROM users")
        end
      end
    RUBY
  end
end
