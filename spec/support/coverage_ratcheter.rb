# frozen_string_literal: true

# Fail if any file under app/ with >200 lines has <70% coverage.
RSpec.configure do |config|
  config.after(:suite) do
    next unless ENV['CI']

    result = SimpleCov.result
    offenders = result.files
      .select { |f| f.filename.include?('/app/') && f.lines.count >= 200 }
      .select { |f| f.covered_percent < 70.0 }
      .map { |f| [ f.filename.sub(Dir.pwd + '/', ''), f.covered_percent.round(1) ] }

    if offenders.any?
      msg = offenders.map { |fn, pct| "- #{fn}: #{pct}% (< 70%)" }.join("\n")
      abort "Per-file coverage guard failed:\n#{msg}"
    end
  end
end
