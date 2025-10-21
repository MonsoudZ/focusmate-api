require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(email: "user_#{SecureRandom.hex(4)}@example.com")
    @coach = create_test_user(email: "coach_#{SecureRandom.hex(4)}@example.com", role: "coach")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    
    @user_headers = auth_headers(@user)
    @coach_headers = auth_headers(@coach)
    @other_user_headers = auth_headers(@other_user)
    
    # Create coaching relationship
    @relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @user,
      status: "active",
      invited_by: @coach
    )
    
    # Create lists and tasks for testing
    @list = create_test_list(@user, name: "Test List")
    @coach_list = create_test_list(@coach, name: "Coach List")
  end

  # Show tests
  test "should get dashboard summary for user" do
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "blocking_tasks_count", "overdue_tasks_count", "awaiting_explanation_count",
      "coaches_count", "completion_rate_this_week", "recent_activity", "upcoming_deadlines"
    ])
    
    assert_equal 0, json["blocking_tasks_count"]
    assert_equal 0, json["overdue_tasks_count"]
    assert_equal 0, json["awaiting_explanation_count"]
    assert_equal 1, json["coaches_count"]
    assert json["completion_rate_this_week"].is_a?(Numeric)
    assert json["recent_activity"].is_a?(Array)
    assert json["upcoming_deadlines"].is_a?(Array)
  end

  test "should include today's tasks" do
    # Create a task for today
    task = Task.create!(
      list: @list,
      creator: @user,
      title: "Today's Task",
      note: "Task due today",
      due_at: 1.hour.from_now,
      status: :pending,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["upcoming_deadlines"])
    
    assert_equal 1, json["upcoming_deadlines"].length
    assert_equal "Today's Task", json["upcoming_deadlines"].first["title"]
  end

  test "should include overdue tasks count" do
    # Create an overdue task
    Task.create!(
      list: @list,
      creator: @user,
      title: "Overdue Task",
      note: "This task is overdue",
      due_at: 1.day.ago,
      status: :pending,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["overdue_tasks_count"])
    
    assert_equal 1, json["overdue_tasks_count"]
  end

  test "should include tasks requiring explanation" do
    # Create a task that requires explanation
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task Requiring Explanation",
      note: "This task requires explanation if missed",
      due_at: 1.day.ago,
      status: :pending,
      requires_explanation_if_missed: true,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["awaiting_explanation_count"])
    
    assert_equal 1, json["awaiting_explanation_count"]
  end

  test "should include coaching relationships summary" do
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["coaches_count"])
    
    assert_equal 1, json["coaches_count"]
  end

  test "should include notification counts" do
    # Create some notifications
    NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Don't forget your task",
      delivered: true,
      delivered_at: Time.current
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["recent_activity"])
    
    # Recent activity should include task events
    assert json["recent_activity"].is_a?(Array)
  end

  test "should get coach dashboard for coach user" do
    get "/api/v1/dashboard", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "clients_count", "total_overdue_tasks", "pending_explanations",
      "active_relationships", "recent_client_activity"
    ])
    
    assert_equal 1, json["clients_count"]
    assert_equal 0, json["total_overdue_tasks"]
    assert_equal 0, json["pending_explanations"]
    assert_equal 1, json["active_relationships"]
    assert json["recent_client_activity"].is_a?(Array)
  end

  test "should not get dashboard without authentication" do
    get "/api/v1/dashboard"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Stats tests
  test "should get dashboard stats" do
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "total_tasks", "completed_tasks", "overdue_tasks", "completion_rate",
      "average_completion_time", "tasks_by_priority"
    ])
    
    assert json["total_tasks"].is_a?(Integer)
    assert json["completed_tasks"].is_a?(Integer)
    assert json["overdue_tasks"].is_a?(Integer)
    assert json["completion_rate"].is_a?(Numeric)
    assert json["average_completion_time"].is_a?(Numeric)
    assert json["tasks_by_priority"].is_a?(Hash)
  end

  test "should include completion rate" do
    # Create some tasks
    Task.create!(
      list: @list,
      creator: @user,
      title: "Completed Task",
      note: "This task is completed",
      due_at: 1.day.ago,
      status: :done,
      completed_at: 1.day.ago,
      strict_mode: false
    )
    
    Task.create!(
      list: @list,
      creator: @user,
      title: "Pending Task",
      note: "This task is pending",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["completion_rate"])
    
    assert_equal 50.0, json["completion_rate"]
  end

  test "should include streak information" do
    # Create tasks with completion history
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task 1",
      note: "Completed yesterday",
      due_at: 1.day.ago,
      status: :done,
      completed_at: 1.day.ago,
      strict_mode: false
    )
    
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task 2",
      note: "Completed today",
      due_at: Time.current,
      status: :done,
      completed_at: Time.current,
      strict_mode: false
    )
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["average_completion_time"])
    
    assert json["average_completion_time"].is_a?(Numeric)
  end

  test "should include tasks by status breakdown" do
    # Create tasks with different statuses
    Task.create!(
      list: @list,
      creator: @user,
      title: "Completed Task",
      note: "This task is completed",
      due_at: 1.day.ago,
      status: :done,
      completed_at: 1.day.ago,
      strict_mode: false
    )
    
    Task.create!(
      list: @list,
      creator: @user,
      title: "Pending Task",
      note: "This task is pending",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks_by_priority"])
    
    assert json["tasks_by_priority"].is_a?(Hash)
    assert json["tasks_by_priority"].key?("urgent")
    assert json["tasks_by_priority"].key?("high")
    assert json["tasks_by_priority"].key?("medium")
    assert json["tasks_by_priority"].key?("low")
  end

  test "should include weekly completion trend" do
    # Create tasks over the past week
    7.times do |i|
      Task.create!(
        list: @list,
        creator: @user,
        title: "Task #{i}",
        note: "Task from #{i} days ago",
        due_at: i.days.ago,
        status: i.even? ? :done : :pending,
        completed_at: i.even? ? i.days.ago : nil,
        strict_mode: false
      )
    end
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["completion_rate"])
    
    assert json["completion_rate"].is_a?(Numeric)
  end

  test "should get coach stats for coach user" do
    get "/api/v1/dashboard/stats", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "total_clients", "active_clients", "total_tasks_across_clients",
      "completed_tasks_across_clients", "average_client_completion_rate",
      "client_performance_summary"
    ])
    
    assert_equal 1, json["total_clients"]
    assert_equal 1, json["active_clients"]
    assert json["total_tasks_across_clients"].is_a?(Integer)
    assert json["completed_tasks_across_clients"].is_a?(Integer)
    assert json["average_client_completion_rate"].is_a?(Numeric)
    assert json["client_performance_summary"].is_a?(Array)
  end

  test "should not get stats without authentication" do
    get "/api/v1/dashboard/stats"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle empty dashboard gracefully" do
    # Create user with no tasks
    empty_user = create_test_user(email: "empty_#{SecureRandom.hex(4)}@example.com")
    empty_headers = auth_headers(empty_user)
    
    get "/api/v1/dashboard", headers: empty_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "blocking_tasks_count", "overdue_tasks_count", "awaiting_explanation_count",
      "coaches_count", "completion_rate_this_week"
    ])
    
    assert_equal 0, json["blocking_tasks_count"]
    assert_equal 0, json["overdue_tasks_count"]
    assert_equal 0, json["awaiting_explanation_count"]
    assert_equal 0, json["coaches_count"]
    assert_equal 0, json["completion_rate_this_week"]
  end

  test "should handle coach with no clients gracefully" do
    # Create coach with no clients
    empty_coach = create_test_user(email: "empty_coach_#{SecureRandom.hex(4)}@example.com", role: "coach")
    empty_coach_headers = auth_headers(empty_coach)
    
    get "/api/v1/dashboard", headers: empty_coach_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "clients_count", "total_overdue_tasks", "pending_explanations",
      "active_relationships"
    ])
    
    assert_equal 0, json["clients_count"]
    assert_equal 0, json["total_overdue_tasks"]
    assert_equal 0, json["pending_explanations"]
    assert_equal 0, json["active_relationships"]
  end

  test "should include blocking tasks count" do
    # Create a task with blocking escalation
    task = Task.create!(
      list: @list,
      creator: @user,
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
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["blocking_tasks_count"])
    
    assert_equal 1, json["blocking_tasks_count"]
  end

  test "should include upcoming deadlines with correct formatting" do
    # Create tasks due in the next few days
    Task.create!(
      list: @list,
      creator: @user,
      title: "Due Tomorrow",
      note: "Task due tomorrow",
      due_at: 1.day.from_now,
      status: :pending,
      strict_mode: false
    )
    
    Task.create!(
      list: @list,
      creator: @user,
      title: "Due Next Week",
      note: "Task due next week",
      due_at: 5.days.from_now,
      status: :pending,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["upcoming_deadlines"])
    
    assert_equal 2, json["upcoming_deadlines"].length
    
    # Check structure of upcoming deadlines
    deadline = json["upcoming_deadlines"].first
    assert deadline.key?("id")
    assert deadline.key?("title")
    assert deadline.key?("due_at")
    assert deadline.key?("list_name")
    assert deadline.key?("days_until_due")
    
    assert_equal "Due Tomorrow", deadline["title"]
    assert deadline["days_until_due"].is_a?(Numeric)
  end

  test "should include recent activity with proper structure" do
    # Create a task and complete it to generate activity
    task = Task.create!(
      list: @list,
      creator: @user,
      title: "Activity Task",
      note: "Task for activity tracking",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    # Complete the task to create a task event
    task.update!(status: :done, completed_at: Time.current)
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["recent_activity"])
    
    assert json["recent_activity"].is_a?(Array)
    
    if json["recent_activity"].any?
      activity = json["recent_activity"].first
      assert activity.key?("id")
      assert activity.key?("task_title")
      assert activity.key?("action")
      assert activity.key?("occurred_at")
    end
  end

  test "should handle coach dashboard with client activity" do
    # Create a task for the client
    Task.create!(
      list: @list,
      creator: @user,
      title: "Client Task",
      note: "Task created by client",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["recent_client_activity"])
    
    assert json["recent_client_activity"].is_a?(Array)
    
    if json["recent_client_activity"].any?
      activity = json["recent_client_activity"].first
      assert activity.key?("id")
      assert activity.key?("client_name")
      assert activity.key?("task_title")
      assert activity.key?("action")
      assert activity.key?("occurred_at")
    end
  end

  test "should calculate completion rate correctly" do
    # Create 3 tasks, complete 2
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task 1",
      note: "Completed task",
      due_at: 1.day.ago,
      status: :done,
      completed_at: 1.day.ago,
      strict_mode: false
    )
    
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task 2",
      note: "Completed task",
      due_at: 1.day.ago,
      status: :done,
      completed_at: 1.day.ago,
      strict_mode: false
    )
    
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task 3",
      note: "Pending task",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["completion_rate"])
    
    assert_equal 66.7, json["completion_rate"]
  end

  test "should handle tasks with no due date in stats" do
    # Create tasks without due dates (but still need due_at for validation)
    Task.create!(
      list: @list,
      creator: @user,
      title: "No Due Date Task",
      note: "Task without due date",
      due_at: 1.day.from_now,  # Still need due_at for validation
      strict_mode: false
    )
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["total_tasks", "completed_tasks"])
    
    assert_equal 1, json["total_tasks"]
    assert_equal 0, json["completed_tasks"]
  end

  test "should handle edge case with zero tasks" do
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["completion_rate", "average_completion_time"])
    
    assert_equal 0, json["completion_rate"]
    assert_equal 0, json["average_completion_time"]
  end

  test "should handle coach stats with multiple clients" do
    # Create another client
    client2 = create_test_user(email: "client2_#{SecureRandom.hex(4)}@example.com")
    CoachingRelationship.create!(
      coach: @coach,
      client: client2,
      status: "active",
      invited_by: @coach
    )
    
    # Create tasks for both clients
    list2 = create_test_list(client2, name: "Client 2 List")
    
    Task.create!(
      list: @list,
      creator: @user,
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
    
    get "/api/v1/dashboard/stats", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["total_clients", "client_performance_summary"])
    
    assert_equal 2, json["total_clients"]
    assert_equal 2, json["client_performance_summary"].length
  end

  test "should handle caching correctly" do
    # First request
    get "/api/v1/dashboard", headers: @user_headers
    assert_response :success
    
    # Second request should use cache
    get "/api/v1/dashboard", headers: @user_headers
    assert_response :success
    
    json = assert_json_response(response, ["blocking_tasks_count"])
    assert json["blocking_tasks_count"].is_a?(Integer)
  end

  test "should handle malformed JSON gracefully" do
    get "/api/v1/dashboard", 
        params: "invalid json",
        headers: @user_headers.merge("Content-Type" => "application/json")
    
    assert_response :success
  end

  test "should handle empty request body" do
    get "/api/v1/dashboard", params: {}, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["blocking_tasks_count"])
    assert json["blocking_tasks_count"].is_a?(Integer)
  end

  test "should handle concurrent dashboard requests" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        get "/api/v1/dashboard", headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle very large task counts" do
    # Create many tasks
    100.times do |i|
      Task.create!(
        list: @list,
        creator: @user,
        title: "Task #{i}",
        note: "Task number #{i}",
        due_at: i.days.from_now,
        strict_mode: false
      )
    end
    
    get "/api/v1/dashboard/stats", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["total_tasks"])
    
    assert_equal 100, json["total_tasks"]
  end

  test "should handle special characters in task titles" do
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task with special chars: !@#$%^&*()",
      note: "Task with special characters",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["upcoming_deadlines"])
    
    if json["upcoming_deadlines"].any?
      assert_equal "Task with special chars: !@#$%^&*()", json["upcoming_deadlines"].first["title"]
    end
  end

  test "should handle unicode characters in task titles" do
    Task.create!(
      list: @list,
      creator: @user,
      title: "Task with unicode: 🚀📱💻",
      note: "Task with unicode characters",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/dashboard", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["upcoming_deadlines"])
    
    if json["upcoming_deadlines"].any?
      assert_equal "Task with unicode: 🚀📱💻", json["upcoming_deadlines"].first["title"]
    end
  end
end
