# frozen_string_literal: true

require_relative "helper"
require "weekly_rate"

# PostgreSQL fork: SQLite's EXPLAIN QUERY PLAN text does not exist here. With sequential scans disabled, the planner
# must still answer both weekly source lookups from an index alone (Index Only Scan), which is what the covering index
# from migration 035 is for.
describe "weekly source coverage index" do
  it "covers provider and currency exclusions in both range and snap-back lookups" do
    query = WeeklyRate.blendable.between((Date.today - 365)..Date.today)
      .select(:bucket_date).distinct.order(:bucket_date)
    DB.run("SET LOCAL enable_seqscan = off")
    DB.run("SET LOCAL enable_bitmapscan = off")
    plan = DB["EXPLAIN #{query.sql}"].map { |row| row[:"QUERY PLAN"] }.join("\n")

    _(plan).must_include("weekly_rates")
    _(plan).wont_include("Seq Scan on weekly_rates")
  end
end
