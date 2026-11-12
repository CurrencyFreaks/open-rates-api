# frozen_string_literal: true

# Development and test entry point: loads both apps (and the shared code they use) so the whole test suite, rubocop and
# every rake task can run from the repository root. Production images load only crawler/boot.rb or api/boot.rb.
require_relative "crawler/boot"
require_relative "api/boot"
