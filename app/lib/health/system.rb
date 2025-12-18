# frozen_string_literal: true

module Health
  class System
    def self.version
      return Rails.application.config.version if Rails.application.config.respond_to?(:version)

      version_file = Rails.root.join("VERSION")
      return File.read(version_file).strip if File.exist?(version_file)

      "unknown"
    rescue
      "unknown"
    end

    def self.uptime_seconds
      boot = Rails.application.config.boot_time
      return "unknown" unless boot

      (Time.current - boot).to_i
    rescue
      "unknown"
    end

    def self.memory
      return { message: "Not available" } unless defined?(GetProcessMem)

      mem = GetProcessMem.new
      { rss_mb: mem.mb.round(2) }
    rescue
      { message: "Not available" }
    end
  end
end
