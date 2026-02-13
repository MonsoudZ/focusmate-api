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

  describe OrphanedAssignmentCleanupJob do
    it "keeps orphaned-assignment cleanup query count near-constant as row volume grows" do
      list_owner = create(:user)
      list = create(:list, user: list_owner)
      assignee = create(:user)
      membership = create(:membership, list: list, user: assignee, role: "editor")

      create_list(:task, 3, list: list, creator: list_owner, assigned_to: assignee)
      membership.destroy!

      small_queries = collect_queries do
        described_class.new.perform
      end

      membership = create(:membership, list: list, user: assignee, role: "editor")
      create_list(:task, 30, list: list, creator: list_owner, assigned_to: assignee)
      membership.destroy!

      large_queries = collect_queries do
        described_class.new.perform
      end

      small_task_queries = table_query_count(small_queries, "tasks")
      large_task_queries = table_query_count(large_queries, "tasks")

      expect(large_task_queries).to be <= (small_task_queries + 1)
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

    it "keeps refresh-token cleanup query count near-constant as inactive families grow" do
      user = create(:user)
      create_inactive_refresh_families(user: user, family_count: 3)

      small_queries = collect_queries do
        described_class.new.perform
      end

      create_inactive_refresh_families(user: user, family_count: 30)

      large_queries = collect_queries do
        described_class.new.perform
      end

      small_refresh_queries = table_query_count(small_queries, "refresh_tokens")
      large_refresh_queries = table_query_count(large_queries, "refresh_tokens")

      expect(large_refresh_queries).to be <= (small_refresh_queries + 1)
    end
  end

  private

  def create_expired_tokens(count)
    count.times do |index|
      JwtDenylist.create!(jti: "expired-#{SecureRandom.uuid}-#{index}", exp: 1.day.ago)
    end
  end

  def create_inactive_refresh_families(user:, family_count:)
    family_count.times do
      family = SecureRandom.uuid
      create(:refresh_token, user: user, family: family, revoked_at: 5.days.ago)
      create(:refresh_token, user: user, family: family, revoked_at: 4.days.ago)
    end
  end
end
