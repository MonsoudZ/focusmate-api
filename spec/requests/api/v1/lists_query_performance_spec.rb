# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lists API Query Performance", type: :request do
  let(:owner) { create(:user) }
  let(:editor) { create(:user) }

  describe "query scaling" do
    it "keeps list index task-count queries near-constant as list count grows" do
      create_lists_with_tasks(owner: owner, list_count: 2, tasks_per_list: 2)

      small_queries = collect_queries do
        auth_get "/api/v1/lists", user: owner
      end

      create_lists_with_tasks(owner: owner, list_count: 8, tasks_per_list: 2)

      large_queries = collect_queries do
        auth_get "/api/v1/lists", user: owner
      end

      expect(response).to have_http_status(:ok)

      small_task_selects = task_select_count(small_queries)
      large_task_selects = task_select_count(large_queries)

      expect(large_task_selects).to be <= (small_task_selects + 1)
    end

    it "keeps membership queries near-constant on list show as task count grows" do
      list = create(:list, user: owner)
      create(:membership, list: list, user: editor, role: "editor")

      create_list(:task, 3, list: list, creator: owner, due_at: 1.day.from_now)
      small_queries = collect_queries do
        auth_get "/api/v1/lists/#{list.id}", user: editor
      end

      create_list(:task, 17, list: list, creator: owner, due_at: 1.day.from_now)
      large_queries = collect_queries do
        auth_get "/api/v1/lists/#{list.id}", user: editor
      end

      expect(response).to have_http_status(:ok)

      small_membership_selects = membership_select_count(small_queries)
      large_membership_selects = membership_select_count(large_queries)

      expect(large_membership_selects).to be <= (small_membership_selects + 1)
    end
  end

  private

  def create_lists_with_tasks(owner:, list_count:, tasks_per_list:)
    create_list(:list, list_count, user: owner).each do |list|
      create_list(:task, tasks_per_list, list: list, creator: owner, due_at: 1.day.from_now)
    end
  end

  def task_select_count(queries)
    queries.count { |sql| sql.start_with?("SELECT") && sql.include?("FROM \"tasks\"") }
  end

  def membership_select_count(queries)
    queries.count { |sql| sql.start_with?("SELECT") && sql.include?("FROM \"memberships\"") }
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
