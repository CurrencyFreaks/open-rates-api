# frozen_string_literal: true

Sequel.migration do
  # PostgreSQL: CREATE/DROP INDEX CONCURRENTLY cannot run inside a transaction.
  no_transaction

  up do
    add_index :rates, :date, concurrently: true
  end

  down do
    drop_index :rates, :date, concurrently: true
  end
end
