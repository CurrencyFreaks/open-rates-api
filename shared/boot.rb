# frozen_string_literal: true

# Shared code (models, blend engine, pegs, currencies) used by both apps. Each app's boot.rb requires this file first.
shared_lib = File.expand_path("lib", __dir__)
$LOAD_PATH << shared_lib unless $LOAD_PATH.include?(shared_lib)
require "currency_patches"
