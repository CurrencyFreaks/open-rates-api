# frozen_string_literal: true

require_relative "helper"
require "open3"
require "tmpdir"

describe "Grouped maintenance writer lock" do
  it "excludes concurrent writes before reading affected source buckets" do
    # A separate process avoids the suite's enclosing rollback transaction. A second real connection plays a concurrent
    # backfill: it must not get the shared write lock (WriteLock) while the rebuild reads the affected source buckets.
    script = <<~RUBY
      require "db"
      Sequel.extension(:migration)
      Sequel::Migrator.run(DB, "crawler/db/migrate")
      require "provider"
      require "blended_weekly_rate"
      require "blended_monthly_rate"
      require "cache"
      require "rake"
      load "crawler/lib/tasks/rollups.rake"
      Provider.seed
      Cache.define_singleton_method(:purge) {}
      row = {provider: "ECB", date: Date.new(2024, 1, 1), base: "USD", quote: "EUR", mid: 0.8}
      DB[:rates].insert(row)
      writer = Sequel.connect(ENV.fetch("DATABASE_URL"))
      try_write = lambda do |values|
        writer.transaction do
          next false unless writer.get(Sequel.function(:pg_try_advisory_xact_lock, WriteLock::KEY))

          writer[:rates].insert(values)
          true
        end
      end
      attempted = false
      blocked = false
      logger = Object.new
      logger.define_singleton_method(:error) { |message| warn message }
      logger.define_singleton_method(:info) do |sql|
        next if attempted || !sql.include?("SELECT") || !sql.include?('FROM "weekly_rates"')

        attempted = true
        blocked = !try_write.call(row.merge(date: Date.new(2024, 1, 2)))
      end
      DB.loggers << logger
      recompute = BlendedWeeklyRate.method(:refresh)
      BlendedWeeklyRate.define_singleton_method(:refresh) do |dates|
        abort "source rollups were not committed before recomputation" if writer[:weekly_rates].empty?
        # This second connection can write only after the source transaction released its lock.
        abort "write lock still held after the source transaction" unless try_write.call(row.merge(date: Date.new(2024, 1, 2)))
        recompute.call(dates)
      end
      rebuild_rollups(DB[:rates].where(provider: "ECB"), "ECB")
      abort "source read was not protected by the writer lock" unless attempted && blocked
      abort "missing grouped output" if BlendedWeeklyRate.empty?
      writer.disconnect
      DB.disconnect
    RUBY

    Dir.mktmpdir do |dir|
      output, status = Open3.capture2e(
        { "DATABASE_URL" => TempDatabase.url(dir), "APP_ENV" => "test" },
        RbConfig.ruby, "-Ilib", "-r./boot", "-e", script,
      )

      _(status.success?).must_equal(true, output)
    end
  end
end
