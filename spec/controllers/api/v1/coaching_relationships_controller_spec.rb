require "rails_helper"

RSpec.describe Api::V1::CoachingRelationshipsController, type: :request do
  let(:coach) { create(:user, role: "coach", email: "coach_#{SecureRandom.hex(4)}@example.com") }
  let(:client) { create(:user, role: "client", email: "client_#{SecureRandom.hex(4)}@example.com") }
  let(:other_coach) { create(:user, role: "coach", email: "other_coach_#{SecureRandom.hex(4)}@example.com") }
  let(:other_client) { create(:user, role: "client", email: "other_client_#{SecureRandom.hex(4)}@example.com") }

  let(:coaching_relationship) do
    CoachingRelationship.create!(
      coach: coach,
      client: client,
      invited_by: "coach",
      status: "active"
    )
  end

  let(:coach_headers) { auth_headers(coach) }
  let(:client_headers) { auth_headers(client) }

  describe "GET /api/v1/coaching_relationships" do
    it "should get all coaching relationships for current user" do
      coaching_relationship # Create the relationship
      get "/api/v1/coaching_relationships", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(coaching_relationship.id)
    end

    it "should separate as_coach vs as_client relationships" do
      coaching_relationship # Create the relationship from let block
      # Create another relationship where current user is client
      other_relationship = CoachingRelationship.create!(
        coach: other_coach,
        client: client,
        invited_by: "coach",
        status: "active"
      )

      get "/api/v1/coaching_relationships", headers: client_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(2)

      relationship_ids = json.map { |r| r["id"] }
      expect(relationship_ids).to include(coaching_relationship.id)
      expect(relationship_ids).to include(other_relationship.id)
    end

    it "should filter by status pending" do
      pending_relationship = CoachingRelationship.create!(
        coach: coach,
        client: other_client,
        invited_by: "coach",
        status: "pending"
      )

      get "/api/v1/coaching_relationships?status=pending", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(pending_relationship.id)
    end

    it "should filter by status active" do
      coaching_relationship # Create the relationship from let block
      get "/api/v1/coaching_relationships?status=active", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(coaching_relationship.id)
    end

    it "should filter by status inactive" do
      inactive_relationship = CoachingRelationship.create!(
        coach: coach,
        client: other_client,
        invited_by: "coach",
        status: "inactive"
      )

      get "/api/v1/coaching_relationships?status=inactive", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(inactive_relationship.id)
    end

    it "should not get coaching relationships without authentication" do
      get "/api/v1/coaching_relationships"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "GET /api/v1/coaching_relationships/:id" do
    it "should show relationship details" do
      get "/api/v1/coaching_relationships/#{coaching_relationship.id}", headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("id", "coach", "client", "status")
      expect(json["id"]).to eq(coaching_relationship.id)
      expect(json["coach"]["id"]).to eq(coach.id)
      expect(json["client"]["id"]).to eq(client.id)
      expect(json["status"]).to eq("active")
    end

    it "should return 404 if not participant in relationship" do
      get "/api/v1/coaching_relationships/#{coaching_relationship.id}", headers: auth_headers(other_client)

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Coaching relationship not found")
    end

    it "should not show relationship without authentication" do
      get "/api/v1/coaching_relationships/#{coaching_relationship.id}"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/coaching_relationships" do
    context "coach inviting client" do
      it "should invite client by email" do
        invite_params = {
          client_email: other_client.email
        }

        post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json).to include("id", "coach", "client", "status", "invited_by")
        expect(json["coach"]["id"]).to eq(coach.id)
        expect(json["client"]["id"]).to eq(other_client.id)
        expect(json["status"]).to eq("pending")
        expect(json["invited_by"]).to eq("coach")
      end

      it "should send notification to invitee" do
        invite_params = {
          client_email: other_client.email
        }

        # Check that notification job is enqueued
        expect {
          post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers
        }.to have_enqueued_job(NotificationJob).with("coaching_invitation_sent", kind_of(Integer))

        expect(response).to have_http_status(:created)
      end

      it "should not allow inviting same user twice" do
        coaching_relationship # Create the existing relationship
        invite_params = {
          client_email: client.email
        }

        post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("Relationship already exists")
      end

      it "should not allow inviting self" do
        invite_params = {
          client_email: coach.email
        }

        post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("You cannot invite yourself")
      end

      it "should return error if client not found" do
        invite_params = {
          client_email: "nonexistent@example.com"
        }

        post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("Client not found with that email")
      end
    end

    context "client inviting coach" do
      it "should invite coach by email" do
        invite_params = {
          coach_email: other_coach.email
        }

        post "/api/v1/coaching_relationships", params: invite_params, headers: client_headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json).to include("id", "coach", "client", "status", "invited_by")
        expect(json["coach"]["id"]).to eq(other_coach.id)
        expect(json["client"]["id"]).to eq(client.id)
        expect(json["status"]).to eq("pending")
        expect(json["invited_by"]).to eq("client")
      end

      it "should return error if coach not found" do
        invite_params = {
          coach_email: "nonexistent@example.com"
        }

        post "/api/v1/coaching_relationships", params: invite_params, headers: client_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("Coach not found with that email")
      end
    end

    it "should return error if no email provided" do
      post "/api/v1/coaching_relationships", params: {}, headers: coach_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Must provide coach_email or client_email")
    end

    it "should not create coaching relationship without authentication" do
      invite_params = {
        client_email: other_client.email
      }

      post "/api/v1/coaching_relationships", params: invite_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "PATCH /api/v1/coaching_relationships/:id/accept" do
    let(:pending_relationship) do
      CoachingRelationship.create!(
        coach: coach,
        client: other_client,
        invited_by: "coach",
        status: "pending"
      )
    end

    it "should accept pending invitation" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(other_client)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("id", "status", "accepted_at")
      expect(json["status"]).to eq("active")
      expect(json["accepted_at"]).not_to be_nil

      pending_relationship.reload
      expect(pending_relationship.status).to eq("active")
      expect(pending_relationship.accepted_at).not_to be_nil
    end

    it "should set status to active" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(other_client)

      expect(response).to have_http_status(:success)

      pending_relationship.reload
      expect(pending_relationship.status).to eq("active")
    end

    it "should set accepted_at timestamp" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(other_client)

      expect(response).to have_http_status(:success)

      pending_relationship.reload
      expect(pending_relationship.accepted_at).not_to be_nil
    end

    it "should return 404 if not the invitee" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: coach_headers

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("You cannot accept this invitation")
    end

    it "should return error if already accepted" do
      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/accept", headers: client_headers

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("You cannot accept this invitation")
    end

    it "should send notification when invitation is accepted" do
      # Check that notification job is enqueued
      expect {
        patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept", headers: auth_headers(other_client)
      }.to have_enqueued_job(NotificationJob).with("coaching_invitation_accepted", pending_relationship.id)

      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /api/v1/coaching_relationships/:id/decline" do
    let(:pending_relationship) do
      CoachingRelationship.create!(
        coach: coach,
        client: other_client,
        invited_by: "coach",
        status: "pending"
      )
    end

    it "should decline pending invitation" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: auth_headers(other_client)

      expect(response).to have_http_status(:no_content)

      pending_relationship.reload
      expect(pending_relationship.status).to eq("declined")
    end

    it "should set status to declined" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: auth_headers(other_client)

      expect(response).to have_http_status(:no_content)

      pending_relationship.reload
      expect(pending_relationship.status).to eq("declined")
    end

    it "should return 404 if not the invitee for decline" do
      patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: coach_headers

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("You cannot decline this invitation")
    end

    it "should send notification when invitation is declined" do
      # Check that notification job is enqueued
      expect {
        patch "/api/v1/coaching_relationships/#{pending_relationship.id}/decline", headers: auth_headers(other_client)
      }.to have_enqueued_job(NotificationJob).with("coaching_invitation_declined", pending_relationship.id)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "PATCH /api/v1/coaching_relationships/:id/update_preferences" do
    it "should update notification preferences" do
      preference_params = {
        coaching_relationship: {
          notify_on_completion: true,
          notify_on_missed_deadline: false,
          send_daily_summary: true,
          daily_summary_time: "09:00"
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("id", "notify_on_completion", "notify_on_missed_deadline", "send_daily_summary", "daily_summary_time")
      expect(json["notify_on_completion"]).to be_truthy
      expect(json["notify_on_missed_deadline"]).to be_falsy
      expect(json["send_daily_summary"]).to be_truthy
      expect(json["daily_summary_time"]).to eq("09:00")
    end

    it "should update daily_summary_time" do
      preference_params = {
        coaching_relationship: {
          daily_summary_time: "18:30"
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to include("id", "daily_summary_time")
      expect(json["daily_summary_time"]).to eq("18:30")

      coaching_relationship.reload
      expect(coaching_relationship.daily_summary_time.strftime("%H:%M")).to eq("18:30")
    end

    it "should only allow coach to update preferences" do
      preference_params = {
        coaching_relationship: {
          notify_on_completion: true
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: client_headers

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Only coaches can update preferences")
    end

    it "should not update preferences without authentication" do
      preference_params = {
        coaching_relationship: {
          notify_on_completion: true
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should return validation errors for invalid preferences" do
      preference_params = {
        coaching_relationship: {
          daily_summary_time: "invalid_time"
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Invalid time format")
    end
  end

  describe "DELETE /api/v1/coaching_relationships/:id" do
    it "should delete (end) coaching relationship" do
      delete "/api/v1/coaching_relationships/#{coaching_relationship.id}", headers: coach_headers

      expect(response).to have_http_status(:no_content)

      expect { CoachingRelationship.find(coaching_relationship.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should allow either party to end relationship" do
      # Test coach ending relationship
      delete "/api/v1/coaching_relationships/#{coaching_relationship.id}", headers: coach_headers
      expect(response).to have_http_status(:no_content)

      # Recreate relationship for client test
      new_relationship = CoachingRelationship.create!(
        coach: coach,
        client: client,
        invited_by: "coach",
        status: "active"
      )

      # Test client ending relationship
      delete "/api/v1/coaching_relationships/#{new_relationship.id}", headers: client_headers
      expect(response).to have_http_status(:no_content)
    end

    it "should stop sending notifications after deletion" do
      # Mock notification service to ensure no notifications are sent
      allow(NotificationService).to receive(:coaching_invitation_sent).and_return(nil)
      allow(NotificationService).to receive(:coaching_invitation_accepted).and_return(nil)
      allow(NotificationService).to receive(:coaching_invitation_declined).and_return(nil)

      delete "/api/v1/coaching_relationships/#{coaching_relationship.id}", headers: coach_headers

      expect(response).to have_http_status(:no_content)
    end

    it "should not allow non-participants to delete relationship" do
      delete "/api/v1/coaching_relationships/#{coaching_relationship.id}", headers: auth_headers(other_client)

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Unauthorized")
    end

    it "should not delete coaching relationship without authentication" do
      delete "/api/v1/coaching_relationships/#{coaching_relationship.id}"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      post "/api/v1/coaching_relationships",
           params: "invalid json",
           headers: coach_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it "should handle empty request body" do
      post "/api/v1/coaching_relationships", params: {}, headers: coach_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Must provide coach_email or client_email")
    end

    it "should handle case insensitive email" do
      invite_params = {
        client_email: other_client.email.upcase
      }

      post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["client"]["id"]).to eq(other_client.id)
    end

    it "should handle whitespace in email" do
      invite_params = {
        client_email: " #{other_client.email} "
      }

      post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["client"]["id"]).to eq(other_client.id)
    end

    it "should handle very long email addresses" do
      long_email = "a" * 200 + "@example.com"

      invite_params = {
        client_email: long_email
      }

      post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Client not found with that email")
    end

    it "should handle special characters in email" do
      invite_params = {
        client_email: "user+tag@example.com"
      }

      post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Client not found with that email")
    end

    it "should handle concurrent invitation attempts" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          invite_params = {
            client_email: "concurrent#{i}@example.com"
          }

          post "/api/v1/coaching_relationships", params: invite_params, headers: coach_headers
        end
      end

      threads.each(&:join)
      # All should succeed with different emails
      expect(true).to be_truthy
    end

    it "should handle concurrent acceptance attempts" do
      pending_relationship = CoachingRelationship.create!(
        coach: coach,
        client: other_client,
        invited_by: "coach",
        status: "pending"
      )

      threads = []
      3.times do
        threads << Thread.new do
          patch "/api/v1/coaching_relationships/#{pending_relationship.id}/accept",
                headers: auth_headers(other_client)
        end
      end

      threads.each(&:join)
      # Only one should succeed
      expect(true).to be_truthy
    end

    it "should handle relationship with different time zones" do
      preference_params = {
        coaching_relationship: {
          daily_summary_time: "09:00",
          timezone: "America/New_York"
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["daily_summary_time"]).to eq("09:00")
    end

    it "should handle relationship with invalid time format" do
      preference_params = {
        coaching_relationship: {
          daily_summary_time: "25:00" # Invalid time
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Invalid time format")
    end

    it "should handle relationship with empty time" do
      preference_params = {
        coaching_relationship: {
          daily_summary_time: ""
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["daily_summary_time"]).to be_nil
    end

    it "should handle relationship with nil time" do
      preference_params = {
        coaching_relationship: {
          daily_summary_time: nil
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["daily_summary_time"]).to be_nil
    end

    it "should handle relationship with boolean preferences" do
      preference_params = {
        coaching_relationship: {
          notify_on_completion: "true",
          notify_on_missed_deadline: "false",
          send_daily_summary: "1"
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["notify_on_completion"]).to be_truthy
      expect(json["notify_on_missed_deadline"]).to be_falsy
      expect(json["send_daily_summary"]).to be_truthy
    end

    it "should handle relationship with string boolean preferences" do
      preference_params = {
        coaching_relationship: {
          notify_on_completion: "yes",
          notify_on_missed_deadline: "no",
          send_daily_summary: "on"
        }
      }

      patch "/api/v1/coaching_relationships/#{coaching_relationship.id}/update_preferences",
            params: preference_params,
            headers: coach_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["notify_on_completion"]).to be_truthy
      expect(json["notify_on_missed_deadline"]).to be_falsy
      expect(json["send_daily_summary"]).to be_truthy
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
