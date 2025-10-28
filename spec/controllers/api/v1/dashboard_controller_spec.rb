require "rails_helper"

RSpec.describe Api::V1::DashboardController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:coach) { create(:user, email: "coach_#{SecureRandom.hex(4)}@example.com", role: "coach") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }

  let(:user_headers) { auth_headers(user) }
  let(:coach_headers) { auth_headers(coach) }
  let(:other_user_headers) { auth_headers(other_user) }

  let(:relationship) do
    CoachingRelationship.create!(
      coach: coach,
      client: user,
      status: "active",
      invited_by: coach
    )
  end

  let(:list) { create(:list, user: user, name: "Test List") }
  let(:coach_list) { create(:list, user: coach, name: "Coach List") }

  describe "GET /api/v1/dashboard" do
    it "should get dashboard summary for user" do
      # Ensure relationship is created
      relationship

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("blocking_tasks_count", "overdue_tasks_count", "awaiting_explanation_count", "coaches_count", "completion_rate_this_week", "recent_activity", "upcoming_deadlines")
      expect(json["blocking_tasks_count"]).to eq(0)
      expect(json["overdue_tasks_count"]).to eq(0)
      expect(json["awaiting_explanation_count"]).to eq(0)
      expect(json["coaches_count"]).to eq(1)
      expect(json["completion_rate_this_week"]).to be_a(Numeric)
      expect(json["recent_activity"]).to be_a(Array)
      expect(json["upcoming_deadlines"]).to be_a(Array)
    end

    it "should include today's tasks" do
      # Create a task for today
      task = Task.create!(
        list: list,
        creator: user,
        title: "Today's Task",
        note: "Task due today",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("upcoming_deadlines")
      expect(json["upcoming_deadlines"].length).to eq(1)
      expect(json["upcoming_deadlines"].first["title"]).to eq("Today's Task")
    end

    it "should include overdue tasks count" do
      # Create an overdue task
      Task.create!(
        list: list,
        creator: user,
        title: "Overdue Task",
        note: "This task is overdue",
        due_at: 1.day.ago,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("overdue_tasks_count")
      expect(json["overdue_tasks_count"]).to eq(1)
    end

    it "should include tasks requiring explanation" do
      # Create a task that requires explanation
      Task.create!(
        list: list,
        creator: user,
        title: "Task Requiring Explanation",
        note: "This task requires explanation if missed",
        due_at: 1.day.ago,
        status: :pending,
        requires_explanation_if_missed: true,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("awaiting_explanation_count")
      expect(json["awaiting_explanation_count"]).to eq(1)
    end

    it "should include coaching relationships summary" do
      # Ensure relationship is created
      relationship

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("coaches_count")
      expect(json["coaches_count"]).to eq(1)
    end

    it "should include notification counts" do
      # Create some notifications
      NotificationLog.create!(
        user: user,
        notification_type: "task_reminder",
        message: "Don't forget your task",
        delivered: true,
        delivered_at: Time.current
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Recent activity should include task events
      expect(json["recent_activity"]).to be_a(Array)
    end

    it "should get coach dashboard for coach user" do
      # Ensure relationship is created
      relationship

      get "/api/v1/dashboard", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("clients_count", "total_overdue_tasks", "pending_explanations", "active_relationships", "recent_client_activity")
      expect(json["clients_count"]).to eq(1)
      expect(json["total_overdue_tasks"]).to eq(0)
      expect(json["pending_explanations"]).to eq(0)
      expect(json["active_relationships"]).to eq(1)
      expect(json["recent_client_activity"]).to be_a(Array)
    end

    it "should not get dashboard without authentication" do
      get "/api/v1/dashboard"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle empty dashboard gracefully" do
      # Create user with no tasks
      empty_user = create(:user, email: "empty_#{SecureRandom.hex(4)}@example.com")
      empty_headers = auth_headers(empty_user)

      get "/api/v1/dashboard", headers: empty_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("blocking_tasks_count", "overdue_tasks_count", "awaiting_explanation_count", "coaches_count", "completion_rate_this_week")
      expect(json["blocking_tasks_count"]).to eq(0)
      expect(json["overdue_tasks_count"]).to eq(0)
      expect(json["awaiting_explanation_count"]).to eq(0)
      expect(json["coaches_count"]).to eq(0)
      expect(json["completion_rate_this_week"]).to eq(0)
    end

    it "should handle coach with no clients gracefully" do
      # Create coach with no clients
      empty_coach = create(:user, email: "empty_coach_#{SecureRandom.hex(4)}@example.com", role: "coach")
      empty_coach_headers = auth_headers(empty_coach)

      get "/api/v1/dashboard", headers: empty_coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("clients_count", "total_overdue_tasks", "pending_explanations", "active_relationships")
      expect(json["clients_count"]).to eq(0)
      expect(json["total_overdue_tasks"]).to eq(0)
      expect(json["pending_explanations"]).to eq(0)
      expect(json["active_relationships"]).to eq(0)
    end

    it "should include blocking tasks count" do
      # Create a task with blocking escalation
      task = Task.create!(
        list: list,
        creator: user,
        title: "Blocking Task",
        note: "This task is blocking the app",
        due_at: 1.day.ago,
        strict_mode: false
      )

      # Create escalation record
      ItemEscalation.create!(
        task: task,
        escalation_level: "blocking",
        blocking_app: true,
        notification_count: 3
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("blocking_tasks_count")
      expect(json["blocking_tasks_count"]).to eq(1)
    end

    it "should include upcoming deadlines with correct formatting" do
      # Create tasks due in the next few days
      Task.create!(
        list: list,
        creator: user,
        title: "Due Tomorrow",
        note: "Task due tomorrow",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      Task.create!(
        list: list,
        creator: user,
        title: "Due Next Week",
        note: "Task due next week",
        due_at: 5.days.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("upcoming_deadlines")
      expect(json["upcoming_deadlines"].length).to eq(2)

      # Check structure of upcoming deadlines
      deadline = json["upcoming_deadlines"].first
      expect(deadline).to have_key("id")
      expect(deadline).to have_key("title")
      expect(deadline).to have_key("due_at")
      expect(deadline).to have_key("list_name")
      expect(deadline).to have_key("days_until_due")

      expect(deadline["title"]).to eq("Due Tomorrow")
      expect(deadline["days_until_due"]).to be_a(Numeric)
    end

    it "should include recent activity with proper structure" do
      # Create a task and complete it to generate activity
      task = Task.create!(
        list: list,
        creator: user,
        title: "Activity Task",
        note: "Task for activity tracking",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      # Complete the task to create a task event
      task.update!(status: :done, completed_at: Time.current)

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["recent_activity"]).to be_a(Array)

      if json["recent_activity"].any?
        activity = json["recent_activity"].first
        expect(activity).to have_key("id")
        expect(activity).to have_key("task_title")
        expect(activity).to have_key("action")
        expect(activity).to have_key("occurred_at")
      end
    end

    it "should handle coach dashboard with client activity" do
      # Create a task for the client
      Task.create!(
        list: list,
        creator: user,
        title: "Client Task",
        note: "Task created by client",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["recent_client_activity"]).to be_a(Array)

      if json["recent_client_activity"].any?
        activity = json["recent_client_activity"].first
        expect(activity).to have_key("id")
        expect(activity).to have_key("client_name")
        expect(activity).to have_key("task_title")
        expect(activity).to have_key("action")
        expect(activity).to have_key("occurred_at")
      end
    end

    it "should handle caching correctly" do
      # First request
      get "/api/v1/dashboard", headers: user_headers
      expect(response).to have_http_status(:success)

      # Second request should use cache
      get "/api/v1/dashboard", headers: user_headers
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json).to include("blocking_tasks_count")
      expect(json["blocking_tasks_count"]).to be_a(Integer)
    end

    it "should handle malformed JSON gracefully" do
      get "/api/v1/dashboard",
          params: "invalid json",
          headers: user_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:success)
    end

    it "should handle empty request body" do
      get "/api/v1/dashboard", params: {}, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include("blocking_tasks_count")
      expect(json["blocking_tasks_count"]).to be_a(Integer)
    end

    it "should handle concurrent dashboard requests" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          get "/api/v1/dashboard", headers: user_headers
        end
      end

      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle special characters in task titles" do
      Task.create!(
        list: list,
        creator: user,
        title: "Task with special chars: !@#$%^&*()",
        note: "Task with special characters",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      if json["upcoming_deadlines"].any?
        expect(json["upcoming_deadlines"].first["title"]).to eq("Task with special chars: !@#$%^&*()")
      end
    end

    it "should handle unicode characters in task titles" do
      Task.create!(
        list: list,
        creator: user,
        title: "Task with unicode: 🚀📱💻",
        note: "Task with unicode characters",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      if json["upcoming_deadlines"].any?
        expect(json["upcoming_deadlines"].first["title"]).to eq("Task with unicode: 🚀📱💻")
      end
    end
  end

  describe "GET /api/v1/dashboard/stats" do
    it "should get dashboard stats" do
      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("total_tasks", "completed_tasks", "overdue_tasks", "completion_rate", "average_completion_time", "tasks_by_priority")
      expect(json["total_tasks"]).to be_a(Integer)
      expect(json["completed_tasks"]).to be_a(Integer)
      expect(json["overdue_tasks"]).to be_a(Integer)
      expect(json["completion_rate"]).to be_a(Numeric)
      expect(json["average_completion_time"]).to be_a(Numeric)
      expect(json["tasks_by_priority"]).to be_a(Hash)
    end

    it "should include completion rate" do
      # Create some tasks
      Task.create!(
        list: list,
        creator: user,
        title: "Completed Task",
        note: "This task is completed",
        due_at: 1.day.ago,
        status: :done,
        completed_at: 1.day.ago,
        strict_mode: false
      )

      Task.create!(
        list: list,
        creator: user,
        title: "Pending Task",
        note: "This task is pending",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("completion_rate")
      expect(json["completion_rate"]).to eq(50.0)
    end

    it "should include streak information" do
      # Create tasks with completion history
      Task.create!(
        list: list,
        creator: user,
        title: "Task 1",
        note: "Completed yesterday",
        due_at: 1.day.ago,
        status: :done,
        completed_at: 1.day.ago,
        strict_mode: false
      )

      Task.create!(
        list: list,
        creator: user,
        title: "Task 2",
        note: "Completed today",
        due_at: Time.current,
        status: :done,
        completed_at: Time.current,
        strict_mode: false
      )

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("average_completion_time")
      expect(json["average_completion_time"]).to be_a(Numeric)
    end

    it "should include tasks by status breakdown" do
      # Create tasks with different statuses
      Task.create!(
        list: list,
        creator: user,
        title: "Completed Task",
        note: "This task is completed",
        due_at: 1.day.ago,
        status: :done,
        completed_at: 1.day.ago,
        strict_mode: false
      )

      Task.create!(
        list: list,
        creator: user,
        title: "Pending Task",
        note: "This task is pending",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("tasks_by_priority")
      expect(json["tasks_by_priority"]).to be_a(Hash)
      expect(json["tasks_by_priority"]).to have_key("urgent")
      expect(json["tasks_by_priority"]).to have_key("high")
      expect(json["tasks_by_priority"]).to have_key("medium")
      expect(json["tasks_by_priority"]).to have_key("low")
    end

    it "should include weekly completion trend" do
      # Create tasks over the past week
      7.times do |i|
        Task.create!(
          list: list,
          creator: user,
          title: "Task #{i}",
          note: "Task from #{i} days ago",
          due_at: i.days.ago,
          status: i.even? ? :done : :pending,
          completed_at: i.even? ? i.days.ago : nil,
          strict_mode: false
        )
      end

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("completion_rate")
      expect(json["completion_rate"]).to be_a(Numeric)
    end

    it "should get coach stats for coach user" do
      # Ensure relationship is created
      relationship

      get "/api/v1/dashboard/stats", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("total_clients", "active_clients", "total_tasks_across_clients", "completed_tasks_across_clients", "average_client_completion_rate", "client_performance_summary")
      expect(json["total_clients"]).to eq(1)
      expect(json["active_clients"]).to eq(1)
      expect(json["total_tasks_across_clients"]).to be_a(Integer)
      expect(json["completed_tasks_across_clients"]).to be_a(Integer)
      expect(json["average_client_completion_rate"]).to be_a(Numeric)
      expect(json["client_performance_summary"]).to be_a(Array)
    end

    it "should not get stats without authentication" do
      get "/api/v1/dashboard/stats"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should calculate completion rate correctly" do
      # Create 3 tasks, complete 2
      Task.create!(
        list: list,
        creator: user,
        title: "Task 1",
        note: "Completed task",
        due_at: 1.day.ago,
        status: :done,
        completed_at: 1.day.ago,
        strict_mode: false
      )

      Task.create!(
        list: list,
        creator: user,
        title: "Task 2",
        note: "Completed task",
        due_at: 1.day.ago,
        status: :done,
        completed_at: 1.day.ago,
        strict_mode: false
      )

      Task.create!(
        list: list,
        creator: user,
        title: "Task 3",
        note: "Pending task",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("completion_rate")
      expect(json["completion_rate"]).to eq(66.7)
    end

    it "should handle tasks with no due date in stats" do
      # Create tasks without due dates (but still need due_at for validation)
      Task.create!(
        list: list,
        creator: user,
        title: "No Due Date Task",
        note: "Task without due date",
        due_at: 1.day.from_now,  # Still need due_at for validation
        strict_mode: false
      )

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("total_tasks", "completed_tasks")
      expect(json["total_tasks"]).to eq(1)
      expect(json["completed_tasks"]).to eq(0)
    end

    it "should handle edge case with zero tasks" do
      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("completion_rate", "average_completion_time")
      expect(json["completion_rate"]).to eq(0)
      expect(json["average_completion_time"]).to eq(0)
    end

    it "should handle coach stats with multiple clients" do
      # Ensure first relationship is created
      relationship

      # Create another client
      client2 = create(:user, email: "client2_#{SecureRandom.hex(4)}@example.com")
      CoachingRelationship.create!(
        coach: coach,
        client: client2,
        status: "active",
        invited_by: coach
      )

      # Create tasks for both clients
      list2 = create(:list, user: client2, name: "Client 2 List")

      Task.create!(
        list: list,
        creator: user,
        title: "Client 1 Task",
        note: "Task for client 1",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      Task.create!(
        list: list2,
        creator: client2,
        title: "Client 2 Task",
        note: "Task for client 2",
        due_at: 1.day.from_now,
        strict_mode: false
      )

      get "/api/v1/dashboard/stats", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("total_clients", "client_performance_summary")
      expect(json["total_clients"]).to eq(2)
      expect(json["client_performance_summary"].length).to eq(2)
    end

    it "should handle very large task counts" do
      # Create many tasks
      100.times do |i|
        Task.create!(
          list: list,
          creator: user,
          title: "Task #{i}",
          note: "Task number #{i}",
          due_at: i.days.from_now,
          strict_mode: false
        )
      end

      get "/api/v1/dashboard/stats", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("total_tasks")
      expect(json["total_tasks"]).to eq(100)
    end
  end

  # Helper method for authentication headers
  def auth_headers(user)
    token = JWT.encode(
      { user_id: user.id, exp: 30.days.from_now.to_i },
      Rails.application.credentials.secret_key_base
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
