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
    let!(:overdue_task) { create(:task, list: list, creator: user, due_at: 1.day.ago, status: :pending, title: "Overdue", skip_due_at_validation: true) }
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

    context "with non-UTC timezone at boundary" do
      # User in America/New_York (UTC-5). Outer around freezes to
      # 2024-01-15 12:00 UTC = 2024-01-15 07:00 EST.
      # NY day boundaries: 05:00 UTC .. 04:59:59 UTC+1day
      let(:ny_user) { create(:user, timezone: "America/New_York") }
      let(:ny_list) { create(:list, user: ny_user) }

      it "returns tasks based on user timezone, not UTC" do
        # 23:59 EST Jan 15 = 04:59 UTC Jan 16 → should be "due_today"
        late_tonight = create(:task, list: ny_list, creator: ny_user,
                              due_at: Time.utc(2024, 1, 16, 4, 59, 0),
                              status: :pending, title: "Late tonight")

        # 00:01 EST Jan 16 = 05:01 UTC Jan 16 → should NOT be "due_today"
        early_tomorrow = create(:task, list: ny_list, creator: ny_user,
                                due_at: Time.utc(2024, 1, 16, 5, 1, 0),
                                status: :pending, title: "Early tomorrow")

        auth_get "/api/v1/today", user: ny_user

        expect(response).to have_http_status(:ok)

        today_ids = json_response["due_today"].map { |t| t["id"] }
        expect(today_ids).to include(late_tonight.id)
        expect(today_ids).not_to include(early_tomorrow.id)
      end
    end

    context "with timezone query param" do
      it "uses param timezone over stored user timezone" do
        # User stored as UTC, but request says America/New_York (UTC-5).
        # Task at 04:59 UTC Jan 16 = 23:59 EST Jan 15 → due_today in NY, but
        # in UTC that's already Jan 16 → would NOT be due_today without the param.
        task = create(:task, list: list, creator: user,
                      due_at: Time.utc(2024, 1, 16, 4, 59, 0),
                      status: :pending, title: "Late in NY")

        auth_get "/api/v1/today", user: user, params: { timezone: "America/New_York" }

        expect(response).to have_http_status(:ok)
        today_ids = json_response["due_today"].map { |t| t["id"] }
        expect(today_ids).to include(task.id)
      end

      it "falls back to stored timezone when param is absent" do
        ny_user = create(:user, timezone: "America/New_York")
        ny_list = create(:list, user: ny_user)
        task = create(:task, list: ny_list, creator: ny_user,
                      due_at: Time.utc(2024, 1, 16, 4, 59, 0),
                      status: :pending, title: "Late in NY")

        auth_get "/api/v1/today", user: ny_user

        today_ids = json_response["due_today"].map { |t| t["id"] }
        expect(today_ids).to include(task.id)
      end

      it "falls back to stored timezone when param is invalid" do
        ny_user = create(:user, timezone: "America/New_York")
        ny_list = create(:list, user: ny_user)
        # 04:59 UTC Jan 16 = 23:59 EST Jan 15 → due_today in NY
        task = create(:task, list: ny_list, creator: ny_user,
                      due_at: Time.utc(2024, 1, 16, 4, 59, 0),
                      status: :pending, title: "Late in NY")

        auth_get "/api/v1/today", user: ny_user, params: { timezone: "Fake/Zone" }

        expect(response).to have_http_status(:ok)
        # Invalid param falls back to stored timezone (America/New_York), not UTC
        today_ids = json_response["due_today"].map { |t| t["id"] }
        expect(today_ids).to include(task.id)
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
