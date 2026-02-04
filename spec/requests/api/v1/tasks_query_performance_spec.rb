# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tasks API Query Performance", type: :request do
  let(:owner) { create(:user) }
  let(:editor) { create(:user) }
  let(:list) { create(:list, user: owner) }

  before do
    create(:membership, list: list, user: editor, role: "editor")
  end

  describe "membership query behavior" do
    it "avoids per-task membership queries on index" do
      create_list(:task, 3, list: list, creator: owner, due_at: 1.day.from_now)

      small_queries = collect_queries do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: editor
      end

      create_list(:task, 17, list: list, creator: owner, due_at: 1.day.from_now)

      large_queries = collect_queries do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: editor
      end

      expect(response).to have_http_status(:ok)

      small_membership_selects = small_queries.count do |sql|
        sql.start_with?("SELECT") && sql.include?("FROM \"memberships\"")
      end
      large_membership_selects = large_queries.count do |sql|
        sql.start_with?("SELECT") && sql.include?("FROM \"memberships\"")
      end

      expect(large_membership_selects).to be <= (small_membership_selects + 1)
    end

    it "avoids per-task membership queries on search" do
      create_list(:task, 3, list: list, creator: owner, title: "Focus task", due_at: 1.day.from_now)

      small_queries = collect_queries do
        auth_get "/api/v1/tasks/search", user: editor, params: { q: "Focus" }
      end

      create_list(:task, 17, list: list, creator: owner, title: "Focus task", due_at: 1.day.from_now)

      large_queries = collect_queries do
        auth_get "/api/v1/tasks/search", user: editor, params: { q: "Focus" }
      end

      expect(response).to have_http_status(:ok)

      small_membership_selects = small_queries.count do |sql|
        sql.start_with?("SELECT") && sql.include?("FROM \"memberships\"")
      end
      large_membership_selects = large_queries.count do |sql|
        sql.start_with?("SELECT") && sql.include?("FROM \"memberships\"")
      end

      expect(large_membership_selects).to be <= (small_membership_selects + 1)
    end
  end

  private

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
