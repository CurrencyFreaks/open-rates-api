# frozen_string_literal: true

require "sequel"

# Shared SQL bucket expressions for weekly and monthly aggregation. Used by Rate#downsample, rollup migrations, and
# rollup refresh.
module Bucket
  class << self
    # SQLite strftime('%W') semantics: weeks start on Monday, days before the year's first Monday are week 0, and the
    # bucket date is 1 January plus seven days per week number. Reproduced exactly so buckets match upstream.
    def week(date_column = :date)
      date = Sequel.cast(date_column, Date)
      day_of_year = Sequel.function(:extract, Sequel.lit("doy FROM ?", date))
      iso_weekday = Sequel.function(:extract, Sequel.lit("isodow FROM ?", date))
      week_num = Sequel.function(:div, Sequel.cast(day_of_year + 7 - iso_weekday, Integer), 7)
      year_start = Sequel.cast(Sequel.function(:date_trunc, "year", date), Date)
      Sequel.cast(year_start + (Sequel.cast(week_num, Integer) * 7), Date)
    end

    def month(date_column = :date)
      Sequel.cast(Sequel.function(:date_trunc, "month", Sequel.cast(date_column, Date)), Date)
    end

    def expression(precision, date_column = :date)
      case precision.to_s
      when "week" then week(date_column)
      when "month" then month(date_column)
      end
    end

    # A date range holding every date of the bucket, so a scan can seek a date index before the exact bucket test. Week
    # buckets count whole weeks from 1 January, so a week's dates sit from 7 days before its bucket date to 5 after.
    def span(precision, bucket_column, date_column = :date)
      from, to = precision.to_s == "week" ? ["-7 days", "6 days"] : ["0 days", "1 month"]
      bucket = Sequel.cast(bucket_column, Date)
      Sequel.&(
        Sequel[date_column] >= Sequel.cast(bucket + Sequel.cast(from, :interval), Date),
        Sequel[date_column] < Sequel.cast(bucket + Sequel.cast(to, :interval), Date),
      )
    end
  end
end
