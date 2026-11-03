# frozen_string_literal: true

Sequel.migration do
  up do
    # PostgreSQL fork: SQLite's printf('%.12g', x) has no PostgreSQL equivalent. This helper rounds a double to 12
    # significant digits (RatePrecision::DIGITS) and is used by migrations 025, 031 and 033 and by RatePrecision.sql.
    run <<~SQL
      CREATE OR REPLACE FUNCTION frankfurter_round_digits(x double precision) RETURNS double precision
      LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
        SELECT CASE
          WHEN x IS NULL OR x = 0 OR x = 'NaN' OR x = 'Infinity' OR x = '-Infinity' THEN x
          ELSE round(x::text::numeric, 11 - floor(log(abs(x::text::numeric)))::int)::double precision
        END
      $$
    SQL

    create_table :rates do
      Date    :date,     null: false
      String  :base,     null: false
      String  :quote,    null: false
      Float   :rate,     null: false
      String  :provider, null: false

      index [:provider, :date, :quote], unique: true
    end
  end

  down do
    drop_table :rates
  end
end
