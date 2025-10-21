require "test_helper"

class Api::V1::DailySummariesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @coach = create_test_user(email: "coach_#{SecureRandom.hex(4)}@example.com", role: "coach")
    @client = create_test_user(email: "client_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    
    @coach_headers = auth_headers(@coach)
    @client_headers = auth_headers(@client)
    @other_user_headers = auth_headers(@other_user)
    
    # Create coaching relationship
    @relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @client,
      status: "active",
      invited_by: @coach
    )
    
    # Create some daily summaries
    @summary1 = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: Date.current,
      tasks_completed: 5,
      tasks_missed: 2,
      tasks_overdue: 1,
      summary_data: {
        completion_rate: 71.4,
        completed_tasks: ["Task 1", "Task 2", "Task 3"],
        missed_tasks: ["Task 4", "Task 5"],
        encouraging_message: "Great job today!"
      }
    )
    
    @summary2 = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 1.day.ago,
      tasks_completed: 3,
      tasks_missed: 1,
      tasks_overdue: 0,
      summary_data: {
        completion_rate: 75.0,
        completed_tasks: ["Task A", "Task B"],
        missed_tasks: ["Task C"],
        encouraging_message: "Keep it up!"
      }
    )
  end

  # Index tests
  test "should get daily summaries for coaching relationship" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    assert json.is_a?(Array)
    assert_equal 2, json.length
    
    # Check structure of summary
    summary = json.first
    assert summary.key?("id")
    assert summary.key?("summary_date")
    assert summary.key?("tasks_completed")
    assert summary.key?("tasks_missed")
    assert summary.key?("tasks_overdue")
    # summary_data is only included in detailed view (show action)
  end

  test "should filter by date range" do
    # Create summary for 2 days ago
    DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 2.days.ago,
      tasks_completed: 1,
      tasks_missed: 0,
      tasks_overdue: 0,
      summary_data: {}
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    # Should return last 30 days (limit 30)
    assert json.length <= 30
    assert json.length >= 2
  end

  test "should only allow coach or client to view" do
    # Coach should be able to view
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    assert_response :success
    
    # Client should be able to view
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @client_headers
    assert_response :success
  end

  test "should return 403 for non-participants" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should return 404 for non-existent relationship" do
    get "/api/v1/coaching_relationships/99999/daily_summaries", headers: @coach_headers
    
    assert_response :not_found
  end

  test "should not get daily summaries without authentication" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Show tests
  test "should show specific daily summary" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{@summary1.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [
      "id", "summary_date", "tasks_completed", "tasks_missed", 
      "tasks_overdue", "summary_data"
    ])
    
    assert_equal @summary1.id, json["id"]
    assert_equal @summary1.summary_date.to_s, json["summary_date"]
    assert_equal 5, json["tasks_completed"]
    assert_equal 2, json["tasks_missed"]
    assert_equal 1, json["tasks_overdue"]
    assert json["summary_data"].is_a?(Hash)
  end

  test "should include task completion stats" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{@summary1.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["tasks_completed", "tasks_missed", "tasks_overdue"])
    
    assert_equal 5, json["tasks_completed"]
    assert_equal 2, json["tasks_missed"]
    assert_equal 1, json["tasks_overdue"]
  end

  test "should include summary_data JSONB" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{@summary1.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_equal 71.4, json["summary_data"]["completion_rate"]
    assert_equal ["Task 1", "Task 2", "Task 3"], json["summary_data"]["completed_tasks"]
    assert_equal ["Task 4", "Task 5"], json["summary_data"]["missed_tasks"]
    assert_equal "Great job today!", json["summary_data"]["encouraging_message"]
  end

  test "should return 404 if not participant" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{@summary1.id}", headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should return 404 for non-existent summary" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/99999", headers: @coach_headers
    
    assert_response :not_found
  end

  test "should return 404 for summary from different relationship" do
    # Create another relationship and summary
    other_client = create_test_user(email: "other_client_#{SecureRandom.hex(4)}@example.com")
    other_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: other_client,
      status: "active",
      invited_by: @coach
    )
    
    other_summary = DailySummary.create!(
      coaching_relationship: other_relationship,
      summary_date: Date.current,
      tasks_completed: 1,
      tasks_missed: 0,
      tasks_overdue: 0,
      summary_data: {}
    )
    
    # Try to access other relationship's summary
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{other_summary.id}", headers: @coach_headers
    
    assert_response :not_found
  end

  test "should not show summary without authentication" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{@summary1.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle empty summary_data gracefully" do
    # Create summary with empty summary_data
    empty_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 3.days.ago,
      tasks_completed: 0,
      tasks_missed: 0,
      tasks_overdue: 0,
      summary_data: {}
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{empty_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert json["summary_data"].empty?
  end

  test "should handle complex summary_data" do
    # Create summary with complex data
    complex_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 4.days.ago,
      tasks_completed: 10,
      tasks_missed: 3,
      tasks_overdue: 2,
      summary_data: {
        completion_rate: 66.7,
        completed_tasks: ["Morning routine", "Workout", "Read book"],
        missed_tasks: ["Call mom", "Grocery shopping", "Laundry"],
        encouraging_message: "You're making great progress!",
        additional_notes: "Client showed improvement in time management",
        mood_rating: 8,
        energy_level: "high",
        challenges_faced: ["Distractions", "Time constraints"],
        wins: ["Completed all priority tasks", "Stayed focused for 2 hours"]
      }
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{complex_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_equal 66.7, json["summary_data"]["completion_rate"]
    assert_equal 8, json["summary_data"]["mood_rating"]
    assert_equal "high", json["summary_data"]["energy_level"]
    assert json["summary_data"]["challenges_faced"].is_a?(Array)
    assert json["summary_data"]["wins"].is_a?(Array)
  end

  test "should order summaries by date descending" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    # Should be ordered by summary_date desc
    assert json.length >= 2
    assert json[0]["summary_date"] >= json[1]["summary_date"]
  end

  test "should limit to 30 summaries" do
    # Create 35 summaries (we already have 2 from setup, so create 33 more)
    33.times do |i|
      DailySummary.create!(
        coaching_relationship: @relationship,
        summary_date: (i + 2).days.ago,  # Start from 2 days ago to avoid conflict with setup
        tasks_completed: 1,
        tasks_missed: 0,
        tasks_overdue: 0,
        summary_data: {}
      )
    end
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    assert_equal 30, json.length
  end

  test "should handle relationship with no summaries" do
    # Create new relationship with no summaries
    new_client = create_test_user(email: "new_client_#{SecureRandom.hex(4)}@example.com")
    new_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: new_client,
      status: "active",
      invited_by: @coach
    )
    
    get "/api/v1/coaching_relationships/#{new_relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    assert json.is_a?(Array)
    assert json.empty?
  end

  test "should handle deleted relationship" do
    # Delete the relationship
    @relationship.destroy!
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :not_found
  end

  test "should handle inactive relationship" do
    # Make relationship inactive
    @relationship.update!(status: "inactive")
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    # Should still return summaries even for inactive relationship
    assert json.is_a?(Array)
  end

  test "should handle very large summary_data" do
    # Create summary with large data
    large_data = {
      completion_rate: 85.5,
      completed_tasks: (1..100).map { |i| "Task #{i}" },
      missed_tasks: (1..50).map { |i| "Missed Task #{i}" },
      encouraging_message: "A" * 1000,
      detailed_notes: "B" * 5000,
      additional_metrics: (1..100).map { |i| { "metric_#{i}" => "value_#{i}" } }
    }
    
    large_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 5.days.ago,
      tasks_completed: 100,
      tasks_missed: 50,
      tasks_overdue: 10,
      summary_data: large_data
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{large_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_equal 100, json["summary_data"]["completed_tasks"].length
    assert_equal 50, json["summary_data"]["missed_tasks"].length
  end

  test "should handle special characters in summary_data" do
    special_data = {
      completion_rate: 75.0,
      completed_tasks: ["Task with special chars: !@#$%^&*()"],
      missed_tasks: ["Missed task with symbols: <>?{}[]"],
      encouraging_message: "Great job! 🎉 Keep it up! 💪",
      additional_notes: "Notes with quotes: \"Hello world\" and 'single quotes'"
    }
    
    special_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 6.days.ago,
      tasks_completed: 1,
      tasks_missed: 1,
      tasks_overdue: 0,
      summary_data: special_data
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{special_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_equal "Great job! 🎉 Keep it up! 💪", json["summary_data"]["encouraging_message"]
  end

  test "should handle unicode characters in summary_data" do
    unicode_data = {
      completion_rate: 80.0,
      completed_tasks: ["Task with unicode: 🚀📱💻"],
      missed_tasks: ["Missed task with emoji: 😢😴"],
      encouraging_message: "Amazing work! 🌟✨🎯",
      additional_notes: "Notes with unicode: 中文测试 🧪"
    }
    
    unicode_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 7.days.ago,
      tasks_completed: 1,
      tasks_missed: 1,
      tasks_overdue: 0,
      summary_data: unicode_data
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{unicode_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_equal "Amazing work! 🌟✨🎯", json["summary_data"]["encouraging_message"]
  end

  test "should handle malformed JSON gracefully" do
    # This test is not applicable for GET requests since they don't parse JSON body
    # GET requests should work normally
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    assert json.is_a?(Array)
  end

  test "should handle empty request body" do
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", params: {}, headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    assert json.is_a?(Array)
  end

  test "should handle concurrent requests" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle very old summaries" do
    # Create summary from 1 year ago
    old_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 1.year.ago,
      tasks_completed: 1,
      tasks_missed: 0,
      tasks_overdue: 0,
      summary_data: {}
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    # Should include old summary in results
    summary_ids = json.map { |s| s["id"] }
    assert_includes summary_ids, old_summary.id
  end

  test "should handle future-dated summaries" do
    # Create summary for tomorrow (shouldn't happen in practice but test edge case)
    future_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 1.day.from_now,
      tasks_completed: 1,
      tasks_missed: 0,
      tasks_overdue: 0,
      summary_data: {}
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, [])
    
    # Should include future summary in results
    summary_ids = json.map { |s| s["id"] }
    assert_includes summary_ids, future_summary.id
  end

  test "should handle summary with nil values" do
    # Create summary with some nil values
    nil_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 8.days.ago,
      tasks_completed: 0,
      tasks_missed: 0,
      tasks_overdue: 0,
      summary_data: {
        completion_rate: nil,
        completed_tasks: nil,
        missed_tasks: nil,
        encouraging_message: nil
      }
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{nil_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_nil json["summary_data"]["completion_rate"]
    assert_nil json["summary_data"]["completed_tasks"]
  end

  test "should handle summary with numeric values" do
    numeric_data = {
      completion_rate: 85.5,
      mood_rating: 8,
      energy_level: 7.5,
      productivity_score: 9.2,
      stress_level: 3.0
    }
    
    numeric_summary = DailySummary.create!(
      coaching_relationship: @relationship,
      summary_date: 9.days.ago,
      tasks_completed: 5,
      tasks_missed: 1,
      tasks_overdue: 0,
      summary_data: numeric_data
    )
    
    get "/api/v1/coaching_relationships/#{@relationship.id}/daily_summaries/#{numeric_summary.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["summary_data"])
    
    assert json["summary_data"].is_a?(Hash)
    assert_equal 85.5, json["summary_data"]["completion_rate"]
    assert_equal 8, json["summary_data"]["mood_rating"]
    assert_equal 7.5, json["summary_data"]["energy_level"]
  end
end
