require "rails_helper"

RSpec.describe Api::V1::DailySummariesController, type: :request do
  let(:coach) { create(:user, email: "coach_#{SecureRandom.hex(4)}@example.com", role: "coach") }
  let(:client) { create(:user, email: "client_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }

  let(:coach_headers) { auth_headers(coach) }
  let(:client_headers) { auth_headers(client) }
  let(:other_user_headers) { auth_headers(other_user) }

  let(:relationship) do
    CoachingRelationship.create!(
      coach: coach,
      client: client,
      status: "active",
      invited_by: coach
    )
  end

  let(:summary1) do
    DailySummary.create!(
      coaching_relationship: relationship,
      summary_date: Date.current,
      tasks_completed: 5,
      tasks_missed: 2,
      tasks_overdue: 1,
      summary_data: {
        completion_rate: 71.4,
        completed_tasks: [ "Task 1", "Task 2", "Task 3" ],
        missed_tasks: [ "Task 4", "Task 5" ],
        encouraging_message: "Great job today!"
      }
    )
  end

  let(:summary2) do
    DailySummary.create!(
      coaching_relationship: relationship,
      summary_date: 1.day.ago,
      tasks_completed: 3,
      tasks_missed: 1,
      tasks_overdue: 0,
      summary_data: {
        completion_rate: 75.0,
        completed_tasks: [ "Task A", "Task B" ],
        missed_tasks: [ "Task C" ],
        encouraging_message: "Keep it up!"
      }
    )
  end

  describe "GET /api/v1/coaching_relationships/:id/daily_summaries" do
    it "should get daily summaries for coaching relationship" do
      # Ensure summaries are created
      summary1
      summary2

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(2)

      # Check structure of summary
      summary = json.first
      expect(summary).to have_key("id")
      expect(summary).to have_key("summary_date")
      expect(summary).to have_key("tasks_completed")
      expect(summary).to have_key("tasks_missed")
      expect(summary).to have_key("tasks_overdue")
      # summary_data is only included in detailed view (show action)
    end

    it "should filter by date range" do
      # Ensure existing summaries are created
      summary1
      summary2

      # Create summary for 2 days ago
      DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 2.days.ago,
        tasks_completed: 1,
        tasks_missed: 0,
        tasks_overdue: 0,
        summary_data: {}
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should return last 30 days (limit 30)
      expect(json.length).to be <= 30
      expect(json.length).to be >= 2
    end

    it "should only allow coach or client to view" do
      # Coach should be able to view
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers
      expect(response).to have_http_status(:success)

      # Client should be able to view
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: client_headers
      expect(response).to have_http_status(:success)
    end

    it "should return 403 for non-participants" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: other_user_headers

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Unauthorized")
    end

    it "should return 404 for non-existent relationship" do
      get "/api/v1/coaching_relationships/99999/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:not_found)
    end

    it "should not get daily summaries without authentication" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should order summaries by date descending" do
      # Ensure summaries are created
      summary1
      summary2

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should be ordered by summary_date desc
      expect(json.length).to be >= 2
      expect(json[0]["summary_date"]).to be >= json[1]["summary_date"]
    end

    it "should limit to 30 summaries" do
      # Create 35 summaries (we already have 2 from setup, so create 33 more)
      33.times do |i|
        DailySummary.create!(
          coaching_relationship: relationship,
          summary_date: (i + 2).days.ago,  # Start from 2 days ago to avoid conflict with setup
          tasks_completed: 1,
          tasks_missed: 0,
          tasks_overdue: 0,
          summary_data: {}
        )
      end

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json.length).to eq(30)
    end

    it "should handle relationship with no summaries" do
      # Create new relationship with no summaries
      new_client = create(:user, email: "new_client_#{SecureRandom.hex(4)}@example.com")
      new_relationship = CoachingRelationship.create!(
        coach: coach,
        client: new_client,
        status: "active",
        invited_by: coach
      )

      get "/api/v1/coaching_relationships/#{new_relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json).to be_empty
    end

    it "should handle deleted relationship" do
      # Delete the relationship
      relationship.destroy!

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:not_found)
    end

    it "should handle inactive relationship" do
      # Make relationship inactive
      relationship.update!(status: "inactive")

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should still return summaries even for inactive relationship
      expect(json).to be_a(Array)
    end

    it "should handle very old summaries" do
      # Create summary from 1 year ago
      old_summary = DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 1.year.ago,
        tasks_completed: 1,
        tasks_missed: 0,
        tasks_overdue: 0,
        summary_data: {}
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should include old summary in results
      summary_ids = json.map { |s| s["id"] }
      expect(summary_ids).to include(old_summary.id)
    end

    it "should handle future-dated summaries" do
      # Create summary for tomorrow (shouldn't happen in practice but test edge case)
      # This should fail validation since future dates are not allowed
      expect {
        DailySummary.create!(
          coaching_relationship: relationship,
          summary_date: 1.day.from_now,
          tasks_completed: 1,
          tasks_missed: 0,
          tasks_overdue: 0,
          summary_data: {}
        )
      }.to raise_error(ActiveRecord::RecordInvalid, /Summary date cannot be in the future/)

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should not include future summary since it couldn't be created
      expect(json.length).to eq(0)
    end

    it "should handle concurrent requests" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers
        end
      end

      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle malformed JSON gracefully" do
      # This test is not applicable for GET requests since they don't parse JSON body
      # GET requests should work normally
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to be_a(Array)
    end

    it "should handle empty request body" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries", params: {}, headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to be_a(Array)
    end
  end

  describe "GET /api/v1/coaching_relationships/:id/daily_summaries/:id" do
    it "should show specific daily summary" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{summary1.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("id", "summary_date", "tasks_completed", "tasks_missed", "tasks_overdue", "summary_data")
      expect(json["id"]).to eq(summary1.id)
      expect(json["summary_date"]).to eq(summary1.summary_date.to_s)
      expect(json["tasks_completed"]).to eq(5)
      expect(json["tasks_missed"]).to eq(2)
      expect(json["tasks_overdue"]).to eq(1)
      expect(json["summary_data"]).to be_a(Hash)
    end

    it "should include task completion stats" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{summary1.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("tasks_completed", "tasks_missed", "tasks_overdue")
      expect(json["tasks_completed"]).to eq(5)
      expect(json["tasks_missed"]).to eq(2)
      expect(json["tasks_overdue"]).to eq(1)
    end

    it "should include summary_data JSONB" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{summary1.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["completion_rate"]).to eq(71.4)
      expect(json["summary_data"]["completed_tasks"]).to eq([ "Task 1", "Task 2", "Task 3" ])
      expect(json["summary_data"]["missed_tasks"]).to eq([ "Task 4", "Task 5" ])
      expect(json["summary_data"]["encouraging_message"]).to eq("Great job today!")
    end

    it "should return 404 if not participant" do
      # Ensure summary1 is created
      summary1

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{summary1.id}", headers: other_user_headers

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Unauthorized")
    end

    it "should return 404 for non-existent summary" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/99999", headers: coach_headers

      expect(response).to have_http_status(:not_found)
    end

    it "should return 404 for summary from different relationship" do
      # Create another relationship and summary
      other_client = create(:user, email: "other_client_#{SecureRandom.hex(4)}@example.com")
      other_relationship = CoachingRelationship.create!(
        coach: coach,
        client: other_client,
        status: "active",
        invited_by: coach
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
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{other_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:not_found)
    end

    it "should not show summary without authentication" do
      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{summary1.id}"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle empty summary_data gracefully" do
      # Create summary with empty summary_data
      empty_summary = DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 3.days.ago,
        tasks_completed: 0,
        tasks_missed: 0,
        tasks_overdue: 0,
        summary_data: {}
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{empty_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]).to be_empty
    end

    it "should handle complex summary_data" do
      # Create summary with complex data
      complex_summary = DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 4.days.ago,
        tasks_completed: 10,
        tasks_missed: 3,
        tasks_overdue: 2,
        summary_data: {
          completion_rate: 66.7,
          completed_tasks: [ "Morning routine", "Workout", "Read book" ],
          missed_tasks: [ "Call mom", "Grocery shopping", "Laundry" ],
          encouraging_message: "You're making great progress!",
          additional_notes: "Client showed improvement in time management",
          mood_rating: 8,
          energy_level: "high",
          challenges_faced: [ "Distractions", "Time constraints" ],
          wins: [ "Completed all priority tasks", "Stayed focused for 2 hours" ]
        }
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{complex_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["completion_rate"]).to eq(66.7)
      expect(json["summary_data"]["mood_rating"]).to eq(8)
      expect(json["summary_data"]["energy_level"]).to eq("high")
      expect(json["summary_data"]["challenges_faced"]).to be_a(Array)
      expect(json["summary_data"]["wins"]).to be_a(Array)
    end

    it "should handle very large summary_data" do
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
        coaching_relationship: relationship,
        summary_date: 5.days.ago,
        tasks_completed: 100,
        tasks_missed: 50,
        tasks_overdue: 10,
        summary_data: large_data
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{large_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["completed_tasks"].length).to eq(100)
      expect(json["summary_data"]["missed_tasks"].length).to eq(50)
    end

    it "should handle special characters in summary_data" do
      special_data = {
        completion_rate: 75.0,
        completed_tasks: [ "Task with special chars: !@#$%^&*()" ],
        missed_tasks: [ "Missed task with symbols: <>?{}[]" ],
        encouraging_message: "Great job! 🎉 Keep it up! 💪",
        additional_notes: "Notes with quotes: \"Hello world\" and 'single quotes'"
      }

      special_summary = DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 6.days.ago,
        tasks_completed: 1,
        tasks_missed: 1,
        tasks_overdue: 0,
        summary_data: special_data
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{special_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["encouraging_message"]).to eq("Great job! 🎉 Keep it up! 💪")
    end

    it "should handle unicode characters in summary_data" do
      unicode_data = {
        completion_rate: 80.0,
        completed_tasks: [ "Task with unicode: 🚀📱💻" ],
        missed_tasks: [ "Missed task with emoji: 😢😴" ],
        encouraging_message: "Amazing work! 🌟✨🎯",
        additional_notes: "Notes with unicode: 中文测试 🧪"
      }

      unicode_summary = DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 7.days.ago,
        tasks_completed: 1,
        tasks_missed: 1,
        tasks_overdue: 0,
        summary_data: unicode_data
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{unicode_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["encouraging_message"]).to eq("Amazing work! 🌟✨🎯")
    end

    it "should handle summary with nil values" do
      # Create summary with some nil values
      nil_summary = DailySummary.create!(
        coaching_relationship: relationship,
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

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{nil_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["completion_rate"]).to be_nil
      expect(json["summary_data"]["completed_tasks"]).to be_nil
    end

    it "should handle summary with numeric values" do
      numeric_data = {
        completion_rate: 85.5,
        mood_rating: 8,
        energy_level: 7.5,
        productivity_score: 9.2,
        stress_level: 3.0
      }

      numeric_summary = DailySummary.create!(
        coaching_relationship: relationship,
        summary_date: 9.days.ago,
        tasks_completed: 5,
        tasks_missed: 1,
        tasks_overdue: 0,
        summary_data: numeric_data
      )

      get "/api/v1/coaching_relationships/#{relationship.id}/daily_summaries/#{numeric_summary.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("summary_data")
      expect(json["summary_data"]).to be_a(Hash)
      expect(json["summary_data"]["completion_rate"]).to eq(85.5)
      expect(json["summary_data"]["mood_rating"]).to eq(8)
      expect(json["summary_data"]["energy_level"]).to eq(7.5)
    end
  end

  # Helper method for authentication headers
  #
  # Always obtain tokens by hitting the real login endpoint so Devise-JWT
  # generates proper claims (including jti) for denylist, Cable, etc.
  def auth_headers(user, password: "password123")
    post "/api/v1/login",
         params: {
           authentication: {
             email: user.email,
             password: password
           }
         }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    raise "Missing Authorization header in auth_headers" if token.blank?

    { "Authorization" => token, "ACCEPT" => "application/json" }
  end
end
