# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Today API Query Performance", type: :request do
  let(:owner) { create(:user, timezone: "UTC") }
  let(:editor) { create(:user, timezone: "UTC") }
  let(:list) { create(:list, user: owner) }

  around do |example|
    travel_to Time.zone.local(2024, 1, 15, 12, 0, 0) do
      example.run
    end
  end

  before do
    create(:membership, list: list, user: editor, role: "editor")
  end

  describe "query scaling" do
    it "keeps membership queries near-constant as today task count grows" do
      create_list(:task, 3, list: list, creator: owner, due_at: Time.current, status: :pending)

      small_queries = collect_queries do
        auth_get "/api/v1/today", user: editor
      end

      create_list(:task, 17, list: list, creator: owner, due_at: Time.current, status: :pending)

      large_queries = collect_queries do
        auth_get "/api/v1/today", user: editor
      end

      expect(response).to have_http_status(:ok)

      small_membership_selects = table_select_count(small_queries, "memberships")
      large_membership_selects = table_select_count(large_queries, "memberships")

      expect(large_membership_selects).to be <= (small_membership_selects + 1)
    end

    it "keeps reschedule-event queries near-constant as today task count grows" do
      create_list(:task, 3, list: list, creator: owner, due_at: Time.current, status: :pending)

      small_queries = collect_queries do
        auth_get "/api/v1/today", user: editor
      end

      create_list(:task, 17, list: list, creator: owner, due_at: Time.current, status: :pending)

      large_queries = collect_queries do
        auth_get "/api/v1/today", user: editor
      end

      expect(response).to have_http_status(:ok)

      small_reschedule_selects = table_select_count(small_queries, "reschedule_events")
      large_reschedule_selects = table_select_count(large_queries, "reschedule_events")

      expect(large_reschedule_selects).to be <= (small_reschedule_selects + 1)
    end
  end
end
