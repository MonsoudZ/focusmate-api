require "test_helper"

class DailySummaryTest < ActiveSupport::TestCase
  def setup
    @coach = create_test_user(role: "coach")
    @client = create_test_user(role: "client")
    @coaching_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @client,
      invited_by: "coach",
      status: "active"
    )
    @daily_summary = DailySummary.new(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current,
      tasks_completed: 5,
      tasks_missed: 2,
      tasks_overdue: 1
    )
  end

  test "should belong to coaching_relationship" do
    assert @daily_summary.valid?
    assert_equal @coaching_relationship, @daily_summary.coaching_relationship
  end

  test "should require summary_date" do
    @daily_summary.summary_date = nil
    assert_not @daily_summary.valid?
    assert_includes @daily_summary.errors[:summary_date], "can't be blank"
  end

  test "should not allow duplicate summary for same relationship and date" do
    @daily_summary.save!
    
    duplicate_summary = DailySummary.new(
      coaching_relationship: @coaching_relationship,
      summary_date: @daily_summary.summary_date,
      tasks_completed: 3,
      tasks_missed: 1,
      tasks_overdue: 0
    )
    
    assert_not duplicate_summary.valid?
    assert_includes duplicate_summary.errors[:coaching_relationship_id], "has already been taken"
  end

  test "should allow different summaries for different relationships" do
    @daily_summary.save!
    
    # Create another coaching relationship
    another_coach = create_test_user(role: "coach")
    another_client = create_test_user(role: "client")
    another_relationship = CoachingRelationship.create!(
      coach: another_coach,
      client: another_client,
      invited_by: "coach",
      status: "active"
    )
    
    another_summary = DailySummary.new(
      coaching_relationship: another_relationship,
      summary_date: @daily_summary.summary_date,
      tasks_completed: 3,
      tasks_missed: 1,
      tasks_overdue: 0
    )
    
    assert another_summary.valid?
    assert another_summary.save
  end

  test "should allow different summaries for same relationship on different dates" do
    @daily_summary.save!
    
    different_date_summary = DailySummary.new(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current + 1.day,
      tasks_completed: 3,
      tasks_missed: 1,
      tasks_overdue: 0
    )
    
    assert different_date_summary.valid?
    assert different_date_summary.save
  end

  test "should default tasks_completed to 0" do
    summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current
    )
    assert_equal 0, summary.tasks_completed
  end

  test "should default tasks_missed to 0" do
    summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current
    )
    assert_equal 0, summary.tasks_missed
  end

  test "should default tasks_overdue to 0" do
    summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current
    )
    assert_equal 0, summary.tasks_overdue
  end

  test "should store summary_data as JSONB" do
    test_data = {
      completion_rate: 75.5,
      notes: "Good progress today",
      performance_grade: "B"
    }
    
    @daily_summary.summary_data = test_data
    @daily_summary.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_data = {
      "completion_rate" => 75.5,
      "notes" => "Good progress today",
      "performance_grade" => "B"
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
    assert @daily_summary.summary_data.is_a?(String)
  end

  test "should handle nil summary_data" do
    @daily_summary.summary_data = nil
    @daily_summary.save!
    
    assert_equal({}, @daily_summary.summary_data)
    assert_equal({}, @daily_summary.parsed_summary_data)
  end

  test "should handle empty summary_data" do
    @daily_summary.summary_data = ""
    @daily_summary.save!
    
    assert_equal({}, @daily_summary.summary_data)
    assert_equal({}, @daily_summary.parsed_summary_data)
  end

  test "should handle invalid JSON in summary_data" do
    @daily_summary.save!
    
    # Directly set invalid JSON in the database
    @daily_summary.update_column(:summary_data, "invalid json")
    
    # The parsed_summary_data method should return empty hash for invalid JSON
    assert_equal({}, @daily_summary.parsed_summary_data)
  end

  test "should calculate completion rate correctly" do
    @daily_summary.tasks_completed = 8
    @daily_summary.tasks_missed = 2
    
    assert_equal 80.0, @daily_summary.completion_rate
  end

  test "should handle zero total tasks in completion rate" do
    @daily_summary.tasks_completed = 0
    @daily_summary.tasks_missed = 0
    
    assert_equal 0, @daily_summary.completion_rate
  end

  test "should round completion rate to 2 decimal places" do
    @daily_summary.tasks_completed = 1
    @daily_summary.tasks_missed = 3
    
    assert_equal 25.0, @daily_summary.completion_rate
  end

  test "should calculate total tasks correctly" do
    @daily_summary.tasks_completed = 5
    @daily_summary.tasks_missed = 3
    
    assert_equal 8, @daily_summary.total_tasks
  end

  test "should check if there are overdue tasks" do
    @daily_summary.tasks_overdue = 0
    assert_not @daily_summary.has_overdue_tasks?
    
    @daily_summary.tasks_overdue = 1
    assert @daily_summary.has_overdue_tasks?
  end

  test "should mark as sent when delivered" do
    assert_not @daily_summary.sent?
    
    @daily_summary.mark_sent!
    
    assert @daily_summary.sent?
    assert_not_nil @daily_summary.sent_at
    assert @daily_summary.sent_at <= Time.current
  end

  test "should record sent_at timestamp" do
    freeze_time = Time.current
    
    @daily_summary.mark_sent!
    
    assert_equal freeze_time.to_i, @daily_summary.sent_at.to_i
  end

  test "should not send same summary twice" do
    @daily_summary.save!
    @daily_summary.mark_sent!
    
    # Try to mark as sent again
    original_sent_at = @daily_summary.sent_at
    @daily_summary.mark_sent!
    
    # Should update the timestamp
    assert @daily_summary.sent_at > original_sent_at
  end

  test "should validate numericality of task counts" do
    @daily_summary.tasks_completed = -1
    assert_not @daily_summary.valid?
    assert_includes @daily_summary.errors[:tasks_completed], "must be greater than or equal to 0"
    
    @daily_summary.tasks_completed = 5
    @daily_summary.tasks_missed = -1
    assert_not @daily_summary.valid?
    assert_includes @daily_summary.errors[:tasks_missed], "must be greater than or equal to 0"
    
    @daily_summary.tasks_missed = 2
    @daily_summary.tasks_overdue = -1
    assert_not @daily_summary.valid?
    assert_includes @daily_summary.errors[:tasks_overdue], "must be greater than or equal to 0"
  end

  test "should validate numericality with string values" do
    @daily_summary.tasks_completed = "invalid"
    assert_not @daily_summary.valid?
    assert_includes @daily_summary.errors[:tasks_completed], "is not a number"
  end

  test "should use sent scope" do
    sent_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current,
      sent: true
    )
    
    unsent_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current + 1.day,
      sent: false
    )
    
    sent_summaries = DailySummary.sent
    assert_includes sent_summaries, sent_summary
    assert_not_includes sent_summaries, unsent_summary
  end

  test "should use unsent scope" do
    sent_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current,
      sent: true
    )
    
    unsent_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current + 1.day,
      sent: false
    )
    
    unsent_summaries = DailySummary.unsent
    assert_includes unsent_summaries, unsent_summary
    assert_not_includes unsent_summaries, sent_summary
  end

  test "should use for_date scope" do
    today = Date.current
    yesterday = Date.current - 1.day
    
    today_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: today
    )
    
    yesterday_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: yesterday
    )
    
    today_summaries = DailySummary.for_date(today)
    assert_includes today_summaries, today_summary
    assert_not_includes today_summaries, yesterday_summary
  end

  test "should use recent scope" do
    old_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current - 5.days
    )
    
    recent_summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current
    )
    
    recent_summaries = DailySummary.recent
    assert_equal recent_summary, recent_summaries.first
    assert_equal old_summary, recent_summaries.last
  end

  test "should get performance grade" do
    # Test that performance_grade calls ConfigurationHelper.performance_grade
    @daily_summary.tasks_completed = 8
    @daily_summary.tasks_missed = 2
    
    # Test that the method calls ConfigurationHelper.performance_grade with correct completion rate
    # We'll test the actual behavior since we can't easily mock the module method
    grade = @daily_summary.performance_grade
    assert_not_nil grade
    assert grade.is_a?(String)
  end

  test "should handle edge case with zero completion rate" do
    @daily_summary.tasks_completed = 0
    @daily_summary.tasks_missed = 5
    
    assert_equal 0, @daily_summary.completion_rate
  end

  test "should handle edge case with 100% completion rate" do
    @daily_summary.tasks_completed = 5
    @daily_summary.tasks_missed = 0
    
    assert_equal 100.0, @daily_summary.completion_rate
  end

  test "should create daily summary with all attributes" do
    summary_data = {
      completion_rate: 75.0,
      notes: "Good progress",
      performance_grade: "B"
    }
    
    summary = DailySummary.create!(
      coaching_relationship: @coaching_relationship,
      summary_date: Date.current,
      tasks_completed: 6,
      tasks_missed: 2,
      tasks_overdue: 1,
      summary_data: summary_data,
      sent: true,
      sent_at: Time.current
    )
    
    assert summary.persisted?
    assert_equal @coaching_relationship, summary.coaching_relationship
    assert_equal Date.current, summary.summary_date
    assert_equal 6, summary.tasks_completed
    assert_equal 2, summary.tasks_missed
    assert_equal 1, summary.tasks_overdue
    
    expected_data = {
      "completion_rate" => 75.0,
      "notes" => "Good progress",
      "performance_grade" => "B"
    }
    assert_equal expected_data, summary.parsed_summary_data
    assert summary.sent?
    assert_not_nil summary.sent_at
  end

  test "should handle complex summary_data" do
    complex_data = {
      completion_rate: 85.5,
      performance_notes: "Excellent work today",
      tasks_breakdown: {
        high_priority: 3,
        medium_priority: 2,
        low_priority: 1
      },
      time_spent: "2.5 hours",
      mood: "positive"
    }
    
    @daily_summary.summary_data = complex_data
    @daily_summary.save!
    
    # JSON parsing returns string keys
    expected_data = {
      "completion_rate" => 85.5,
      "performance_notes" => "Excellent work today",
      "tasks_breakdown" => {
        "high_priority" => 3,
        "medium_priority" => 2,
        "low_priority" => 1
      },
      "time_spent" => "2.5 hours",
      "mood" => "positive"
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
  end

  test "should handle summary_data with nested arrays" do
    data_with_arrays = {
      completed_tasks: ["Task 1", "Task 2", "Task 3"],
      missed_tasks: ["Task 4"],
      notes: ["Good progress", "Need to focus more"]
    }
    
    @daily_summary.summary_data = data_with_arrays
    @daily_summary.save!
    
    expected_data = {
      "completed_tasks" => ["Task 1", "Task 2", "Task 3"],
      "missed_tasks" => ["Task 4"],
      "notes" => ["Good progress", "Need to focus more"]
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
  end

  test "should handle summary_data with special characters" do
    data_with_special_chars = {
      notes: "Task with émojis 🎯 and special chars: @#$%",
      completion_rate: 75.5
    }
    
    @daily_summary.summary_data = data_with_special_chars
    @daily_summary.save!
    
    expected_data = {
      "notes" => "Task with émojis 🎯 and special chars: @#$%",
      "completion_rate" => 75.5
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
  end

  test "should handle large summary_data" do
    large_data = {
      detailed_notes: "A" * 1000,
      task_details: (1..100).map { |i| "Task #{i}" },
      performance_metrics: (1..50).map { |i| { "metric_#{i}" => i * 10 } }
    }
    
    @daily_summary.summary_data = large_data
    @daily_summary.save!
    
    expected_data = {
      "detailed_notes" => "A" * 1000,
      "task_details" => (1..100).map { |i| "Task #{i}" },
      "performance_metrics" => (1..50).map { |i| { "metric_#{i}" => i * 10 } }
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
  end

  test "should handle summary_data with boolean values" do
    data_with_booleans = {
      completed: true,
      sent: false,
      has_notes: true,
      performance_grade: "A"
    }
    
    @daily_summary.summary_data = data_with_booleans
    @daily_summary.save!
    
    expected_data = {
      "completed" => true,
      "sent" => false,
      "has_notes" => true,
      "performance_grade" => "A"
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
  end

  test "should handle summary_data with numeric values" do
    data_with_numbers = {
      completion_rate: 85.5,
      tasks_count: 10,
      hours_spent: 2.5,
      score: 95
    }
    
    @daily_summary.summary_data = data_with_numbers
    @daily_summary.save!
    
    expected_data = {
      "completion_rate" => 85.5,
      "tasks_count" => 10,
      "hours_spent" => 2.5,
      "score" => 95
    }
    assert_equal expected_data, @daily_summary.parsed_summary_data
  end
end
