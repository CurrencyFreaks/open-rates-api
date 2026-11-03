# frozen_string_literal: true

require_relative "helper"
require "open3"
require "tmpdir"

describe "Rate component migrations" do
  it "keeps rates readable through rollback and reapplication without a custom database function" do
    script = <<~RUBY
      require "db"
      Sequel.extension(:migration)
      Sequel::Migrator.run(DB, "db/migrate")
      identity = {provider: "TST", date: Date.new(2026, 9, 1), base: "USD"}
      DB[:rates].multi_insert([
        identity.merge(quote: "EUR", mid: 100, bid: 99, ask: 103),
        identity.merge(quote: "GBP", bid: 1830.59054685, ask: 1831.5063),
        identity.merge(provider: "BOJA", quote: "JPY", bid: 0, ask: 103),
      ])
      expected = DB[:rates].order(:quote).select_map(:rate)

      [32, 30, 33].each do |version|
        Sequel::Migrator.run(DB, "db/migrate", target: version)
        abort "wrong migration version" unless DB[:schema_info].get(:version) == version
        # A standalone connection must read the schema without application callbacks.
        connection = PG.connect(ENV.fetch("DATABASE_URL"))
        actual = connection.exec("SELECT rate FROM rates ORDER BY quote").column_values(0).map(&:to_f)
        connection.close
        abort "rates changed at version \#{version}" unless actual == expected
      end
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
