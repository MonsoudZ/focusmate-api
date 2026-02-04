# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Maintenance Jobs Query Performance", type: :job do
  describe StaleDeviceCleanupJob do
    let(:user) { create(:user) }

    it "keeps device query count near-constant as stale-row volume grows" do
      create_list(:device, 3, user: user, last_seen_at: 100.days.ago)

      small_queries = collect_queries do
        described_class.new.perform
      end

      create_list(:device, 30, user: user, last_seen_at: 100.days.ago)

      large_queries = collect_queries do
        described_class.new.perform
      end

      small_device_queries = table_query_count(small_queries, "devices")
      large_device_queries = table_query_count(large_queries, "devices")

      expect(large_device_queries).to be <= (small_device_queries + 1)
    end
  end

  describe JwtCleanupJob do
    it "keeps jwt denylist query count near-constant as expired-row volume grows" do
      create_expired_tokens(3)

      small_queries = collect_queries do
        described_class.new.perform
      end

      create_expired_tokens(30)

      large_queries = collect_queries do
        described_class.new.perform
      end

      small_jwt_queries = table_query_count(small_queries, "jwt_denylists")
      large_jwt_queries = table_query_count(large_queries, "jwt_denylists")

      expect(large_jwt_queries).to be <= (small_jwt_queries + 1)
    end
  end

  private

  def create_expired_tokens(count)
    count.times do |index|
      JwtDenylist.create!(jti: "expired-#{SecureRandom.uuid}-#{index}", exp: 1.day.ago)
    end
  end

  def table_query_count(queries, table_name)
    queries.count { |sql| sql.include?("\"#{table_name}\"") }
  end

  def collect_queries
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if sql.include?("SCHEMA")
      next if sql.start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE SAVEPOINT")

      queries << sql
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    queries
  end
end
