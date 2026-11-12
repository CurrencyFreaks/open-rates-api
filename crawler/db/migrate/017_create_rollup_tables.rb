# frozen_string_literal: true

require "bucket"

Sequel.migration do
  up do
    create_table(:weekly_rates) do
      column :bucket_date, :date, null: false
      String :provider, null: false
      String :base, null: false
      String :quote, null: false
      Float :rate, null: false

      primary_key [:provider, :bucket_date, :base, :quote]
      index [:bucket_date, :quote]
    end

    create_table(:monthly_rates) do
      column :bucket_date, :date, null: false
      String :provider, null: false
      String :base, null: false
      String :quote, null: false
      Float :rate, null: false

      primary_key [:provider, :bucket_date, :base, :quote]
      index [:bucket_date, :quote]
    end

    # Backfill weekly_rates
    week_bucket = Bucket.week(:date)

    self[:weekly_rates].insert(
      [:bucket_date, :provider, :base, :quote, :rate],
      self[:rates].select(week_bucket, :provider, :base, :quote, Sequel.function(:avg, :rate))
        .group(:provider, :base, :quote, week_bucket),
    )

    # Backfill monthly_rates
    month_bucket = Bucket.month(:date)

    self[:monthly_rates].insert(
      [:bucket_date, :provider, :base, :quote, :rate],
      self[:rates].select(month_bucket, :provider, :base, :quote, Sequel.function(:avg, :rate))
        .group(:provider, :base, :quote, month_bucket),
    )
  end

  down do
    drop_table(:weekly_rates)
    drop_table(:monthly_rates)
  end
end
