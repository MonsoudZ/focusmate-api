# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Today API", type: :request do
  let(:user) { create(:user, timezone: "UTC") }
  let(:list) { create(:list, user: user) }

  around do |example|
    travel_to Time.zone.local(2024, 1, 15, 12, 0, 0) do
      example.run
    end
  end

  describe "GET /api/v1/today" do
    let!(:overdue_task) { create(:task, list: list, creator: user, due_at: 1.day.ago, status: :pending, title: "Overdue") }
    let!(:due_today) { create(:task, list: list, creator: user, due_at: Time.current, status: :pending, title: "Today") }
    let!(:completed_today) { create(:task, list: list, creator: user, due_at: Time.current, status: :done, completed_at: Time.current, title: "Done") }
    let!(:tomorrow_task) { create(:task, list: list, creator: user, due_at: 1.day.from_now, status: :pending, title: "Tomorrow") }

    context "when authenticated" do
      it "returns today's tasks organized by status" do
        auth_get "/api/v1/today", user: user

        expect(response).to have_http_status(:ok)

        overdue_ids = json_response["overdue"].map { |t| t["id"] }
        today_ids = json_response["due_today"].map { |t| t["id"] }
        completed_ids = json_response["completed_today"].map { |t| t["id"] }

        expect(overdue_ids).to include(overdue_task.id)
        expect(today_ids).to include(due_today.id)
        expect(completed_ids).to include(completed_today.id)
        expect(today_ids).not_to include(tomorrow_task.id)
      end

      it "includes stats" do
        auth_get "/api/v1/today", user: user

        expect(json_response["stats"]).to be_present
        expect(json_response["stats"]["total_due_today"]).to be_a(Integer)
        expect(json_response["stats"]["completed_today"]).to be_a(Integer)
        expect(json_response["stats"]["overdue_count"]).to be_a(Integer)
      end

      it "excludes tasks from other users" do
        other_user = create(:user)
        other_list = create(:list, user: other_user)
        other_task = create(:task, list: other_list, creator: other_user, due_at: Time.current)

        auth_get "/api/v1/today", user: user

        all_task_ids = json_response["due_today"].map { |t| t["id"] } +
                       json_response["overdue"].map { |t| t["id"] } +
                       json_response["completed_today"].map { |t| t["id"] }

        expect(all_task_ids).not_to include(other_task.id)
      end

      it "excludes subtasks" do
        subtask = create(:task, list: list, creator: user, due_at: Time.current, parent_task: due_today)

        auth_get "/api/v1/today", user: user

        all_task_ids = json_response["due_today"].map { |t| t["id"] } +
                       json_response["overdue"].map { |t| t["id"] }

        expect(all_task_ids).not_to include(subtask.id)
      end

      it "excludes deleted tasks" do
        overdue_task.soft_delete!

        auth_get "/api/v1/today", user: user

        overdue_ids = json_response["overdue"].map { |t| t["id"] }
        expect(overdue_ids).not_to include(overdue_task.id)
      end

      it "falls back safely when user timezone is invalid" do
        user.update_column(:timezone, "Invalid/Zone")

        auth_get "/api/v1/today", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["stats"]).to be_present
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/today"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
