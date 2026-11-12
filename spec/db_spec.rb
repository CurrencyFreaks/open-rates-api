# frozen_string_literal: true

require "English"
require_relative "helper"

describe "Database connection configuration" do
  def database_name(env)
    `#{env} bundle exec ruby -Ishared/lib -e 'require "db"; puts DB.opts[:database]'`.strip
  end

  it "appends TEST_ENV_NUMBER to test database name when set" do
    _(database_name("env -u DATABASE_URL APP_ENV=test TEST_ENV_NUMBER=3")).must_equal("frankfurter_test_3")
  end

  it "does not append suffix when TEST_ENV_NUMBER is empty" do
    _(database_name("env -u DATABASE_URL APP_ENV=test TEST_ENV_NUMBER=")).must_equal("frankfurter_test")
  end

  it "does not append suffix when TEST_ENV_NUMBER is unset" do
    _(database_name("env -u DATABASE_URL -u TEST_ENV_NUMBER APP_ENV=test")).must_equal("frankfurter_test")
  end

  it "uses DATABASE_URL when set, ignoring TEST_ENV_NUMBER" do
    url = TempDatabase.url

    _(database_name("APP_ENV=test TEST_ENV_NUMBER=3 DATABASE_URL=#{url}")).must_equal(url.split("/").last)
  end

  it "refuses a non-PostgreSQL DATABASE_URL" do
    output = `DATABASE_URL=sqlite://custom.sqlite3 bundle exec ruby -Ishared/lib -e 'require "db"' 2>&1`

    _($CHILD_STATUS.success?).must_equal(false)
    _(output).must_include("uses PostgreSQL")
  end
end
