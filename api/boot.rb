# frozen_string_literal: true

require_relative "../shared/boot"
api_lib = File.expand_path("lib", __dir__)
$LOAD_PATH << api_lib unless $LOAD_PATH.include?(api_lib)
