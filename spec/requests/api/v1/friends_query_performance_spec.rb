# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Friends API Query Performance", type: :request do
  let(:user) { create(:user) }

  describe "query scaling" do
    it "keeps index queries near-constant as friend count grows" do
      create_friends(user: user, count: 3)

      small_queries = collect_queries do
        auth_get "/api/v1/friends", user: user, params: { per_page: 100 }
      end

      create_friends(user: user, count: 27)

      large_queries = collect_queries do
        auth_get "/api/v1/friends", user: user, params: { per_page: 100 }
      end

      expect(response).to have_http_status(:ok)

      small_selects = select_count(small_queries)
      large_selects = select_count(large_queries)

      expect(large_selects).to be <= (small_selects + 1)
    end

    it "keeps exclude-list filtering queries near-constant as friend count grows" do
      list = create(:list, user: user)
      friends = create_friends(user: user, count: 3)
      create(:membership, list: list, user: friends.first, role: "editor")

      small_queries = collect_queries do
        auth_get "/api/v1/friends", user: user, params: { exclude_list_id: list.id, per_page: 100 }
      end

      more_friends = create_friends(user: user, count: 27)
      more_friends.first(5).each do |friend|
        create(:membership, list: list, user: friend, role: "editor")
      end

      large_queries = collect_queries do
        auth_get "/api/v1/friends", user: user, params: { exclude_list_id: list.id, per_page: 100 }
      end

      expect(response).to have_http_status(:ok)

      small_membership_selects = table_select_count(small_queries, "memberships")
      large_membership_selects = table_select_count(large_queries, "memberships")

      expect(large_membership_selects).to be <= (small_membership_selects + 1)
    end
  end

  private

  def create_friends(user:, count:)
    create_list(:user, count).each do |friend|
      Friendship.create_mutual!(user, friend)
    end
  end

  def select_count(queries)
    queries.count { |sql| sql.start_with?("SELECT") }
  end

  def table_select_count(queries, table_name)
    queries.count { |sql| sql.start_with?("SELECT") && sql.include?("FROM \"#{table_name}\"") }
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
