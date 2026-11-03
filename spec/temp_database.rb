# frozen_string_literal: true

require "securerandom"

# PostgreSQL fork: specs that used to point a subprocess at a fresh SQLite file in a temp dir get a fresh, empty
# PostgreSQL database instead. Each one is dropped when the test process exits.
module TempDatabase
  @names = []

  class << self
    def url(_dir = nil)
      name = "frankfurter_tmp_#{SecureRandom.hex(6)}"
      admin { |db| db.run("CREATE DATABASE #{name}") }
      @names << name
      uri_for(name)
    end

    def drop_all
      return if @names.empty?

      admin { |db| @names.each { |name| db.run("DROP DATABASE IF EXISTS #{name} WITH (FORCE)") } }
      @names.clear
    end

    private

    def uri_for(name)
      opts = DB.opts
      auth = opts[:password].to_s.empty? ? opts[:user] : "#{opts[:user]}:#{opts[:password]}"
      "postgres://#{auth}@#{opts[:host]}:#{opts[:port] || 5432}/#{name}"
    end

    def admin
      db = Sequel.connect(DB.opts.merge(database: "postgres", max_connections: 1))
      yield db
    ensure
      db&.disconnect
      Sequel::DATABASES.delete(db)
    end
  end
end

Minitest.after_run { TempDatabase.drop_all } if defined?(Minitest)
at_exit { TempDatabase.drop_all }
