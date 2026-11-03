# frozen_string_literal: true

Sequel.migration do
  up do
    # Old rows retain their exact effective value until their published components can be recovered. Some legacy mids
    # were calculated by an adapter; renaming the column does not establish that a provider published them.
    run "ALTER TABLE rates RENAME COLUMN rate TO mid"
    alter_table(:rates) do
      set_column_allow_null :mid
      add_column :bid, Float
      add_column :ask, Float
    end

    # A virtual column stores no extra value and keeps raw SQL consumers (rollups included) on the same read contract.
    # SQLite's floating-point midpoint and printf differ from Ruby at historical rounding boundaries. Use the same
    # decimal calculation and precision policy as ingest. BOJA historically uses the sell quote when its buying quote is
    # zero; preserve that exception without representing the sell quote as a published mid.
    run <<~SQL
      ALTER TABLE rates ADD COLUMN rate double precision GENERATED ALWAYS AS (
        COALESCE(mid,
          CASE
            WHEN provider = 'BOJA' AND bid = 0 THEN ask
            WHEN bid IS NOT NULL AND ask IS NOT NULL THEN frankfurter_round_digits((bid + ask) / 2.0)
          END
        )
      ) STORED
    SQL
  end

  down do
    run "UPDATE rates SET mid = rate"
    run "ALTER TABLE rates DROP COLUMN rate"
    run "ALTER TABLE rates DROP COLUMN bid"
    run "ALTER TABLE rates DROP COLUMN ask"
    run "ALTER TABLE rates RENAME COLUMN mid TO rate"
    alter_table(:rates) { set_column_not_null :rate }
  end
end
