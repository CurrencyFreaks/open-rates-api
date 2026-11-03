# frozen_string_literal: true

require "sequel"
require "rate_components"

# PostgreSQL fork: DATABASE_URL must point at a PostgreSQL server, for example
#   postgres://frankfurter:secret@postgres:5432/frankfurter
# Without it, a local server is assumed (PGHOST/PGUSER/PGPASSWORD/PGPORT) with one database per APP_ENV, and per
# parallel test worker.
url = ENV.fetch("DATABASE_URL") do
  env = ENV["APP_ENV"]
  worker = ENV["TEST_ENV_NUMBER"]
  suffix = worker && !worker.empty? ? "_#{worker}" : ""
  db_name = env ? "frankfurter_#{env}#{suffix}" : "frankfurter"
  user = ENV.fetch("PGUSER", "postgres")
  password = ENV.fetch("PGPASSWORD", "")
  auth = password.empty? ? user : "#{user}:#{password}"
  "postgres://#{auth}@#{ENV.fetch("PGHOST", "localhost")}:#{ENV.fetch("PGPORT", "5432")}/#{db_name}"
end

unless url.start_with?("postgres")
  abort "This Frankfurter fork uses PostgreSQL. Set DATABASE_URL to a postgres:// URL."
end

max_connections = Integer(ENV.fetch("MAX_THREADS", 5))

# test: false connects on first query, as the SQLite version did, so loading this file never needs a live server.
DB = Sequel.connect(url, max_connections:, test: false)

# SQLite allowed one writer at a time and the code relies on that: backfills, blend refreshes and rollups assume no
# other writer interleaves. PostgreSQL runs writers concurrently, so every write transaction that used to take SQLite's
# write lock (mode: :immediate, or the first write of a backfill) takes this transaction-scoped advisory lock instead.
module WriteLock
  KEY = 0x6672616e # "fran"

  class << self
    def acquire(db = DB)
      db.get(Sequel.function(:pg_advisory_xact_lock, KEY))
    end
  end
end
