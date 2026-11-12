# frozen_string_literal: true

desc "Compare table and live response bytes and require grouped materialized coverage"
task "blend:parity", [:samples] do |_t, args|
  require "blend_parity"

  samples = Integer(args[:samples] || 200)
  abort "blended_rates is empty; run rake blend:rebuild first" if BlendedRate.dataset.empty?

  report = BlendParity.run(samples:)
  puts report
  abort "parity failed or incomplete; see coverage above" unless report.passed?
end
