# frozen_string_literal: true

module Health
  class System
    def self.version
      return Rails.application.config.version if Rails.application.config.respond_to?(:version)

      file = Rails.root.join("VERSION")
      return File.read(file).strip if File.exist?(file)

      "unknown"
    rescue StandardError
      "unknown"
    end

    def self.uptime_seconds
      boot = Rails.application.config.respond_to?(:boot_time) ? Rails.application.config.boot_time : nil
      return nil unless boot

      (Time.current - boot).to_i
    rescue StandardError
      nil
    end

    def self.memory
      return nil unless defined?(GetProcessMem)

      mem = GetProcessMem.new
      { rss_mb: mem.mb.round(2) }
    rescue StandardError
      nil
    end
  end
end
