# frozen_string_literal: true

require_relative "boot"
["crawler/lib/tasks", "api/lib/tasks", "tasks"].each do |dir|
  Dir.glob("#{dir}/*.rake").each { |r| import r }
end
