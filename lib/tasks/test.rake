# frozen_string_literal: true

require "etc"

desc "Run test suite in parallel"
task :spec do
  ENV["APP_ENV"] = "test"
  workers = Integer(ENV.fetch("PARALLEL_WORKERS") { [Etc.nprocessors, 8].min })

  # Clone the migrated and seeded base test database for workers 2..N. PostgreSQL copies a database from a template only
  # while nobody is connected to the template.
  require "db"
  base = DB.opts[:database]
  admin = Sequel.connect(DB.opts.merge(database: "postgres"))
  Sequel::DATABASES.each { |db| db.disconnect unless db.equal?(admin) }
  clones = (2..workers).map { |i| "#{base}_#{i}" }
  clones.each do |name|
    admin.run("DROP DATABASE IF EXISTS #{admin.literal(Sequel.identifier(name))}")
    admin.run("CREATE DATABASE #{admin.literal(Sequel.identifier(name))} " \
              "TEMPLATE #{admin.literal(Sequel.identifier(base))}")
  end

  begin
    cmd = ["bundle", "exec", "parallel_test", "spec/", "-n", workers.to_s, "--type", "test", "--serialize-stdout"]
    system({ "APP_ENV" => "test" }, *cmd) || abort("Tests failed")
  ensure
    clones.each { |name| admin.run("DROP DATABASE IF EXISTS #{admin.literal(Sequel.identifier(name))}") }
    admin.disconnect
  end
end
