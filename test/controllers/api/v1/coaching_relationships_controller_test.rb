require "test_helper"

class Api::V1::CoachingRelationshipsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @coach = create_test_user(role: "coach", email: "coach_#{SecureRandom.hex(4)}@example.com")
    @client = create_test_user(role: "client", email: "client_#{SecureRandom.hex(4)}@example.com")
    @other_coach = create_test_user(role: "coach", email: "other_coach_#{SecureRandom.hex(4)}@example.com")
    @other_client = create_test_user(role: "client", email: "other_client_#{SecureRandom.hex(4)}@example.com")
    
    @coaching_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @client,
      invited_by: "coach",
      status: "active"
    )
    
    @coach_headers = auth_headers(@coach)
    @client_headers = auth_headers(@client)
  end

  # Index tests
  test "should get all coaching relationships for current user" do
    get "/api/v1/coaching_relationships", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @coaching_relationship.id, json.first["id"]
  end

  test "should separate as_coach vs as_client relationships" do
    # Create another relationship where current user is client
    other_relationship = CoachingRelationship.create!(
      coach: @other_coach,
      client: @client,
      invited_by: "coach",
      status: "active"
    )
    
    get "/api/v1/coaching_relationships", headers: @client_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 2, json.length
    
    relationship_ids = json.map { |r| r["id"] }
    assert_includes relationship_ids, @coaching_relationship.id
    assert_includes relationship_ids, other_relationship.id
  end

  test "should filter by status pending" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    get "/api/v1/coaching_relationships?status=pending", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal pending_relationship.id, json.first["id"]
  end

  test "should filter by status active" do
    get "/api/v1/coaching_relationships?status=active", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @coaching_relationship.id, json.first["id"]
  end

  test "should filter by status inactive" do
    inactive_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "inactive"
    )
    
    get "/api/v1/coaching_relationships?status=inactive", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal inactive_relationship.id, json.first["id"]
  end

  test "should not get coaching relationships without authentication" do
    get "/api/v1/coaching_relationships"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Show tests
  test "should show relationship details" do
    get "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "coach", "client", "status"])
    
    assert_equal @coaching_relationship.id, json["id"]
    assert_equal @coach.id, json["coach"]["id"]
    assert_equal @client.id, json["client"]["id"]
    assert_equal "active", json["status"]
  end

  test "should return 404 if not participant in relationship" do
    get "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: auth_headers(@other_client)
    
    assert_error_response(response, :not_found, "Coaching relationship not found")
  end

  test "should not show relationship without authentication" do
    get "/api/v1/coaching_relationships/#{@coaching_relationship.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Create (Invite) tests
  test "coach should invite client by email" do
    invite_params = {
      client_email: @other_client.email
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "coach", "client", "status", "invited_by"])
    
    assert_equal @coach.id, json["coach"]["id"]
    assert_equal @other_client.id, json["client"]["id"]
    assert_equal "pending", json["status"]
    assert_equal "coach", json["invited_by"]
  end

  test "client should invite coach by email" do
    invite_params = {
      coach_email: @other_coach.email
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @client_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "coach", "client", "status", "invited_by"])
    
    assert_equal @other_coach.id, json["coach"]["id"]
    assert_equal @client.id, json["client"]["id"]
    assert_equal "pending", json["status"]
    assert_equal "client", json["invited_by"]
  end

  test "should not allow inviting same user twice" do
    invite_params = {
      client_email: @client.email
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should not allow inviting self" do
    invite_params = {
      client_email: @coach.email
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should send notification to invitee" do
    invite_params = {
      client_email: @other_client.email
    }
    
    # Mock notification service
    NotificationService.expects(:coaching_invitation_sent).with(instance_of(CoachingRelationship))
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_response :created
  end

  test "should return error if coach not found" do
    invite_params = {
      coach_email: "nonexistent@example.com"
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @client_headers
    
    assert_error_response(response, :not_found, "Coach not found with that email")
  end

  test "should return error if client not found" do
    invite_params = {
      client_email: "nonexistent@example.com"
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_error_response(response, :not_found, "Client not found with that email")
  end

  test "should return error if no email provided" do
    post "/api/v1/coaching_relationships", params: {}, headers: @coach_headers
    
    assert_error_response(response, :unprocessable_entity, "Must provide coach_email or client_email")
  end

  test "should not create coaching relationship without authentication" do
    invite_params = {
      client_email: @other_client.email
    }
    
    post "/api/v1/coaching_relationships", params: invite_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Accept tests
  test "should accept pending invitation" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(@other_client)
    
    assert_response :success
    json = assert_json_response(response, ["id", "status", "accepted_at"])
    
    assert_equal "active", json["status"]
    assert_not_nil json["accepted_at"]
    
    pending_relationship.reload
    assert pending_relationship.active?
    assert_not_nil pending_relationship.accepted_at
  end

  test "should set status to active" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(@other_client)
    
    assert_response :success
    
    pending_relationship.reload
    assert pending_relationship.active?
  end

  test "should set accepted_at timestamp" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(@other_client)
    
    assert_response :success
    
    pending_relationship.reload
    assert_not_nil pending_relationship.accepted_at
  end

  test "should return 404 if not the invitee" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: @coach_headers
    
    assert_error_response(response, :forbidden, "You cannot accept this invitation")
  end

  test "should return error if already accepted" do
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/accept", headers: @client_headers
    
    assert_error_response(response, :forbidden, "You cannot accept this invitation")
  end

  test "should send notification when invitation is accepted" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    # Mock notification service
    NotificationService.expects(:coaching_invitation_accepted).with(pending_relationship)
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(@other_client)
    
    assert_response :success
  end

  # Decline tests
  test "should decline pending invitation" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: auth_headers(@other_client)
    
    assert_response :no_content
    
    pending_relationship.reload
    assert pending_relationship.declined?
  end

  test "should set status to declined" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: auth_headers(@other_client)
    
    assert_response :no_content
    
    pending_relationship.reload
    assert pending_relationship.declined?
  end

  test "should return 404 if not the invitee for decline" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: @coach_headers
    
    assert_error_response(response, :forbidden, "You cannot decline this invitation")
  end

  test "should send notification when invitation is declined" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    # Mock notification service
    NotificationService.expects(:coaching_invitation_declined).with(pending_relationship)
    
    patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: auth_headers(@other_client)
    
    assert_response :no_content
  end

  # Update Preferences tests
  test "should update notification preferences" do
    preference_params = {
      coaching_relationship: {
        notify_on_completion: true,
        notify_on_missed_deadline: false,
        send_daily_summary: true,
        daily_summary_time: "09:00"
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "notify_on_completion", "notify_on_missed_deadline", "send_daily_summary", "daily_summary_time"])
    
    assert json["notify_on_completion"]
    assert_not json["notify_on_missed_deadline"]
    assert json["send_daily_summary"]
    assert_equal "09:00", json["daily_summary_time"]
  end

  test "should update daily_summary_time" do
    preference_params = {
      coaching_relationship: {
        daily_summary_time: "18:30"
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "daily_summary_time"])
    
    assert_equal "18:30", json["daily_summary_time"]
    
    @coaching_relationship.reload
    assert_equal "18:30", @coaching_relationship.daily_summary_time
  end

  test "should only allow coach to update preferences" do
    preference_params = {
      coaching_relationship: {
        notify_on_completion: true
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @client_headers
    
    assert_error_response(response, :forbidden, "Only coaches can update preferences")
  end

  test "should not update preferences without authentication" do
    preference_params = {
      coaching_relationship: {
        notify_on_completion: true
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should return validation errors for invalid preferences" do
    preference_params = {
      coaching_relationship: {
        daily_summary_time: "invalid_time"
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  # Delete tests
  test "should delete (end) coaching relationship" do
    delete "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: @coach_headers
    
    assert_response :no_content
    
    assert_raises(ActiveRecord::RecordNotFound) do
      CoachingRelationship.find(@coaching_relationship.id)
    end
  end

  test "should allow either party to end relationship" do
    # Test coach ending relationship
    delete "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: @coach_headers
    assert_response :no_content
    
    # Recreate relationship for client test
    @coaching_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @client,
      invited_by: "coach",
      status: "active"
    )
    
    # Test client ending relationship
    delete "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: @client_headers
    assert_response :no_content
  end

  test "should stop sending notifications after deletion" do
    # Mock notification service to ensure no notifications are sent
    NotificationService.expects(:coaching_invitation_sent).never
    NotificationService.expects(:coaching_invitation_accepted).never
    NotificationService.expects(:coaching_invitation_declined).never
    
    delete "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: @coach_headers
    
    assert_response :no_content
  end

  test "should not allow non-participants to delete relationship" do
    delete "/api/v1/coaching_relationships/#{@coaching_relationship.id}", headers: auth_headers(@other_client)
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should not delete coaching relationship without authentication" do
    delete "/api/v1/coaching_relationships/#{@coaching_relationship.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/coaching_relationships", 
         params: "invalid json",
         headers: @coach_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    post "/api/v1/coaching_relationships", params: {}, headers: @coach_headers
    
    assert_error_response(response, :unprocessable_entity, "Must provide coach_email or client_email")
  end

  test "should handle case insensitive email" do
    invite_params = {
      client_email: @other_client.email.upcase
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "client"])
    assert_equal @other_client.id, json["client"]["id"]
  end

  test "should handle whitespace in email" do
    invite_params = {
      client_email: " #{@other_client.email} "
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "client"])
    assert_equal @other_client.id, json["client"]["id"]
  end

  test "should handle very long email addresses" do
    long_email = "a" * 200 + "@example.com"
    
    invite_params = {
      client_email: long_email
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_error_response(response, :not_found, "Client not found with that email")
  end

  test "should handle special characters in email" do
    invite_params = {
      client_email: "user+tag@example.com"
    }
    
    post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
    
    assert_error_response(response, :not_found, "Client not found with that email")
  end

  test "should handle concurrent invitation attempts" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        invite_params = {
          client_email: "concurrent#{i}@example.com"
        }
        
        post "/api/v1/coaching_relationships", params: invite_params, headers: @coach_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed with different emails
    assert true
  end

  test "should handle concurrent acceptance attempts" do
    pending_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @other_client,
      invited_by: "coach",
      status: "pending"
    )
    
    threads = []
    3.times do
      threads << Thread.new do
        patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", 
              headers: auth_headers(@other_client)
      end
    end
    
    threads.each(&:join)
    # Only one should succeed
    assert true
  end

  test "should handle relationship with different time zones" do
    preference_params = {
      coaching_relationship: {
        daily_summary_time: "09:00",
        timezone: "America/New_York"
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "daily_summary_time"])
    assert_equal "09:00", json["daily_summary_time"]
  end

  test "should handle relationship with invalid time format" do
    preference_params = {
      coaching_relationship: {
        daily_summary_time: "25:00" # Invalid time
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle relationship with empty time" do
    preference_params = {
      coaching_relationship: {
        daily_summary_time: ""
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "daily_summary_time"])
    assert_nil json["daily_summary_time"]
  end

  test "should handle relationship with nil time" do
    preference_params = {
      coaching_relationship: {
        daily_summary_time: nil
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "daily_summary_time"])
    assert_nil json["daily_summary_time"]
  end

  test "should handle relationship with boolean preferences" do
    preference_params = {
      coaching_relationship: {
        notify_on_completion: "true",
        notify_on_missed_deadline: "false",
        send_daily_summary: "1"
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "notify_on_completion", "notify_on_missed_deadline", "send_daily_summary"])
    
    assert json["notify_on_completion"]
    assert_not json["notify_on_missed_deadline"]
    assert json["send_daily_summary"]
  end

  test "should handle relationship with string boolean preferences" do
    preference_params = {
      coaching_relationship: {
        notify_on_completion: "yes",
        notify_on_missed_deadline: "no",
        send_daily_summary: "on"
      }
    }
    
    patch "/api/v1/coaching_relationships/#{@coaching_relationship.id}/update_preferences", 
          params: preference_params, 
          headers: @coach_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "notify_on_completion", "notify_on_missed_deadline", "send_daily_summary"])
    
    assert json["notify_on_completion"]
    assert_not json["notify_on_missed_deadline"]
    assert json["send_daily_summary"]
  end
end
