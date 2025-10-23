require "rails_helper"

RSpec.describe Api::V1::ListSharesController, type: :request do
  let(:list_owner) { create(:user, email: "owner_#{SecureRandom.hex(4)}@example.com") }
  let(:shared_user) { create(:user, email: "shared_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }
  let(:list) { create(:list, owner: list_owner, name: "Shared List") }
  
  let(:list_share) do
    ListShare.create!(
      list: list,
      user: shared_user,
      email: shared_user.email,
      role: "editor",
      status: "accepted",
      can_view: true,
      can_edit: true,
      can_add_items: true,
      can_delete_items: false,
      receive_notifications: true
    )
  end
  
  let(:owner_headers) { auth_headers(list_owner) }
  let(:shared_user_headers) { auth_headers(shared_user) }
  let(:other_user_headers) { auth_headers(other_user) }

  describe "GET /api/v1/lists/:id/shares" do
    it "should get all shares for a list (owner only)" do
      # Trigger the creation of list_share
      list_share
      
      get "/api/v1/lists/#{list.id}/shares", headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(list_share.id)
    end

    it "should return 403 if not list owner for index" do
      get "/api/v1/lists/#{list.id}/shares", headers: other_user_headers
      
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Only list owner can manage shares")
    end

    it "should not get shares without authentication" do
      get "/api/v1/lists/#{list.id}/shares"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/lists/:id/shares" do
    it "should share list with user by email" do
      share_params = {
        email: other_user.email,
        role: "viewer",
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: false,
        receive_notifications: true
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "email", "role", "status")
      expect(json["email"]).to eq(other_user.email)
      expect(json["role"]).to eq("viewer")
      expect(json["status"]).to eq("accepted")
    end

    it "should create with default permissions" do
      share_params = {
        email: other_user.email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "email", "role", "can_view", "can_edit", "can_add_items", "can_delete_items")
      expect(json["email"]).to eq(other_user.email)
      expect(json["role"]).to eq("viewer")
      expect(json["can_view"]).to be_truthy
      expect(json["can_edit"]).to be_falsy
      expect(json["can_add_items"]).to be_falsy
      expect(json["can_delete_items"]).to be_falsy
    end

    it "should create with custom permissions" do
      share_params = {
        email: other_user.email,
        role: "viewer",
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: true,
        receive_notifications: false
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "email", "role", "can_view", "can_edit", "can_add_items", "can_delete_items", "receive_notifications")
      expect(json["email"]).to eq(other_user.email)
      expect(json["role"]).to eq("viewer")
      expect(json["can_view"]).to be_truthy
      expect(json["can_edit"]).to be_truthy
      expect(json["can_add_items"]).to be_truthy
      expect(json["can_delete_items"]).to be_truthy
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should generate invitation_token for non-existent user" do
      share_params = {
        email: "newuser@example.com",
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "email", "status", "invitation_token")
      expect(json["email"]).to eq("newuser@example.com")
      expect(json["status"]).to eq("pending")
      expect(json["invitation_token"]).not_to be_nil
    end

    it "should send email invitation" do
      share_params = {
        email: "invitee@example.com",
        role: "viewer"
      }
      
      # Mock email service
      allow(ListShareMailer).to receive(:invitation_email).and_return(double(deliver_now: true))
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
    end

    it "should return 403 if not list owner" do
      share_params = {
        email: other_user.email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: other_user_headers
      
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Only list owner can manage shares")
    end

    it "should return error if already shared with user" do
      # Trigger the creation of list_share
      list_share
      
      share_params = {
        email: shared_user.email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("id", "email")
      expect(json["id"]).to eq(list_share.id)
      expect(json["email"]).to eq(shared_user.email)
    end

    it "should return error if email is blank" do
      share_params = {
        email: "",
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Email is required")
    end

    it "should not create share without authentication" do
      share_params = {
        email: other_user.email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "GET /api/v1/lists/:id/shares/:id" do
    it "should show share details" do
      # Trigger the creation of list_share
      list_share
      
      get "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "email", "role", "status", "can_view", "can_edit")
      expect(json["id"]).to eq(list_share.id)
      expect(json["email"]).to eq(shared_user.email)
      expect(json["role"]).to eq("editor")
      expect(json["status"]).to eq("accepted")
    end

    it "should return 404 if not list owner or shared user" do
      get "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: other_user_headers
      
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Unauthorized")
    end

    it "should allow shared user to view their own share" do
      get "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: shared_user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include("id", "email")
      expect(json["id"]).to eq(list_share.id)
      expect(json["email"]).to eq(shared_user.email)
    end

    it "should not show share without authentication" do
      get "/api/v1/lists/#{list.id}/shares/#{list_share.id}"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "PATCH /api/v1/lists/:id/shares/:id/update_permissions" do
    it "should update share permissions (owner only)" do
      permission_params = {
        permissions: {
          can_edit: false,
          can_add_items: false,
          can_delete_items: true,
          receive_notifications: false
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications")
      expect(json["can_edit"]).to be_falsy
      expect(json["can_add_items"]).to be_falsy
      expect(json["can_delete_items"]).to be_truthy
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should update can_edit, can_add_items, can_delete_items" do
      permission_params = {
        permissions: {
          can_edit: true,
          can_add_items: true,
          can_delete_items: true
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "can_edit", "can_add_items", "can_delete_items")
      expect(json["can_edit"]).to be_truthy
      expect(json["can_add_items"]).to be_truthy
      expect(json["can_delete_items"]).to be_truthy
    end

    it "should update receive_notifications" do
      permission_params = {
        permissions: {
          receive_notifications: false
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "receive_notifications")
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should return 403 if not list owner for permissions" do
      permission_params = {
        permissions: {
          can_edit: false
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: other_user_headers
      
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Only list owner can manage shares")
    end

    it "should not update permissions without authentication" do
      permission_params = {
        permissions: {
          can_edit: false
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/lists/:id/shares/:id/accept" do
    let(:pending_share) do
      ListShare.create!(
        list: list,
        email: "nonexistent@example.com",
        role: "viewer",
        status: "pending",
        invitation_token: SecureRandom.hex(32)
      )
    end

    it "should accept list share invitation" do
      # Trigger the creation of pending_share
      pending_share
      
      post "/api/v1/lists/#{list.id}/shares/#{pending_share.id}/accept", 
           headers: other_user_headers
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      
      expect(json).to include("id", "status", "user_id", "accepted_at")
      expect(json["status"]).to eq("accepted")
      expect(json["user_id"]).to eq(other_user.id)
      expect(json["accepted_at"]).not_to be_nil
    end

    it "should link user_id to share" do
      post "/api/v1/lists/#{list.id}/shares/#{pending_share.id}/accept", 
           headers: other_user_headers
      
      expect(response).to have_http_status(:success)
      
      pending_share.reload
      expect(pending_share.user_id).to eq(other_user.id)
    end

    it "should set status to accepted" do
      post "/api/v1/lists/#{list.id}/shares/#{pending_share.id}/accept", 
           headers: other_user_headers
      
      expect(response).to have_http_status(:success)
      
      pending_share.reload
      expect(pending_share.status).to eq("accepted")
    end

    it "should return error if invitation_token invalid" do
      pending_share.update!(invitation_token: nil)
      
      post "/api/v1/lists/#{list.id}/shares/#{pending_share.id}/accept", 
           headers: other_user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Invitation is not pending")
    end

    it "should return error if already accepted" do
      post "/api/v1/lists/#{list.id}/shares/#{list_share.id}/accept", 
           headers: shared_user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Invitation is not pending")
    end
  end

  describe "POST /api/v1/list_shares/accept" do
    let(:pending_share_email) { "pending_user_#{SecureRandom.hex(4)}@example.com" }
    
    let(:pending_share) do
      ListShare.create!(
        list: list,
        email: pending_share_email,
        role: "viewer",
        status: "pending",
        invitation_token: SecureRandom.hex(32)
      )
    end

    let(:pending_user) do
      User.create!(
        email: pending_share_email,
        password: "password123",
        name: "Pending User",
        role: "client"
      )
    end

    it "should accept invitation via token (email link)" do
      # Trigger the creation of pending_share first, then create the user
      pending_share
      pending_user
      
      post "/api/v1/list_shares/accept", 
           params: { token: pending_share.invitation_token }
      
      expect(response).to have_http_status(:no_content)
      
      pending_share.reload
      expect(pending_share.status).to eq("accepted")
      expect(pending_share.user_id).to eq(pending_user.id)
      expect(pending_share.invitation_token).to be_nil
    end

    it "should accept invitation via token without authentication" do
      pending_share
      pending_user
      
      post "/api/v1/list_shares/accept", 
           params: { token: pending_share.invitation_token }
      
      expect(response).to have_http_status(:no_content)
      
      pending_share.reload
      expect(pending_share.status).to eq("accepted")
      expect(pending_share.user_id).to eq(pending_user.id)
    end
  end

  describe "POST /api/v1/lists/:id/shares/:id/decline" do
    let(:pending_share) do
      ListShare.create!(
        list: list,
        email: "nonexistent@example.com",
        role: "viewer",
        status: "pending",
        invitation_token: SecureRandom.hex(32)
      )
    end

    it "should decline list share invitation" do
      # Trigger the creation of pending_share
      pending_share
      
      post "/api/v1/lists/#{list.id}/shares/#{pending_share.id}/decline", 
           headers: other_user_headers
      
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("message")
      expect(json["message"]).to eq("Invitation declined")
      
      pending_share.reload
      expect(pending_share.status).to eq("declined")
    end

    it "should set status to declined" do
      post "/api/v1/lists/#{list.id}/shares/#{pending_share.id}/decline", 
           headers: other_user_headers
      
      expect(response).to have_http_status(:success)
      
      pending_share.reload
      expect(pending_share.status).to eq("declined")
    end

    it "should return error if not pending" do
      post "/api/v1/lists/#{list.id}/shares/#{list_share.id}/decline", 
           headers: shared_user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Invitation is not pending")
    end
  end

  describe "DELETE /api/v1/lists/:id/shares/:id" do
    it "should revoke share (owner only)" do
      delete "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: owner_headers
      
      expect(response).to have_http_status(:no_content)
      
      expect { ListShare.find(list_share.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should remove user's access to list" do
      delete "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: owner_headers
      
      expect(response).to have_http_status(:no_content)
      
      # Check that user can no longer access the list
      get "/api/v1/lists/#{list.id}", headers: shared_user_headers
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Unauthorized")
    end

    it "should notify user of revocation" do
      # Mock notification service
      allow(ListShareMailer).to receive(:revocation_notification).and_return(double(deliver_now: true))
      
      delete "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: owner_headers
      
      expect(response).to have_http_status(:no_content)
    end

    it "shared user should leave list voluntarily" do
      # Create a share where the user can leave voluntarily
      voluntary_share = ListShare.create!(
        list: list,
        user: other_user,
        email: other_user.email,
        role: "viewer",
        status: "accepted"
      )
      
      delete "/api/v1/lists/#{list.id}/shares/#{voluntary_share.id}", headers: other_user_headers
      
      expect(response).to have_http_status(:no_content)
      
      expect { ListShare.find(voluntary_share.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should not allow non-owner to revoke share" do
      delete "/api/v1/lists/#{list.id}/shares/#{list_share.id}", headers: other_user_headers
      
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Only list owner or share owner can delete this share")
    end

    it "should not revoke share without authentication" do
      delete "/api/v1/lists/#{list.id}/shares/#{list_share.id}"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      post "/api/v1/lists/#{list.id}/shares", 
           params: "invalid json",
           headers: owner_headers.merge("Content-Type" => "application/json")
      
      expect(response).to have_http_status(:bad_request)
    end

    it "should handle empty request body" do
      post "/api/v1/lists/#{list.id}/shares", params: {}, headers: owner_headers
      
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Email is required")
    end

    it "should handle case insensitive email" do
      share_params = {
        email: other_user.email.upcase,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(other_user.email.downcase)
    end

    it "should handle whitespace in email" do
      share_params = {
        email: " #{other_user.email} ",
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(other_user.email)
    end

    it "should handle very long email addresses" do
      long_email = "a" * 200 + "@example.com"
      
      share_params = {
        email: long_email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json).to include("id", "email", "status")
      expect(json["email"]).to eq(long_email)
      expect(json["status"]).to eq("pending")
    end

    it "should handle special characters in email" do
      special_email = "user+tag@example.com"
      
      share_params = {
        email: special_email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(special_email)
    end

    it "should handle concurrent share creation" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          share_params = {
            email: "concurrent#{i}@example.com",
            role: "viewer"
          }
          
          post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
        end
      end
      
      threads.each(&:join)
      # All should succeed with different emails
      expect(true).to be_truthy
    end

    it "should handle concurrent permission updates" do
      permission_params = {
        permissions: {
          can_edit: true,
          can_add_items: true
        }
      }
      
      threads = []
      3.times do
        threads << Thread.new do
          patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
                params: permission_params, 
                headers: owner_headers
        end
      end
      
      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle boolean permission values" do
      permission_params = {
        permissions: {
          can_edit: "true",
          can_add_items: "false",
          can_delete_items: "1",
          receive_notifications: "0"
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications")
      expect(json["can_edit"]).to be_truthy
      expect(json["can_add_items"]).to be_falsy
      expect(json["can_delete_items"]).to be_truthy
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should handle string boolean permission values" do
      permission_params = {
        permissions: {
          can_edit: "yes",
          can_add_items: "no",
          can_delete_items: "on",
          receive_notifications: "off"
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications")
      expect(json["can_edit"]).to be_truthy
      expect(json["can_add_items"]).to be_falsy
      expect(json["can_delete_items"]).to be_truthy
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should handle nil permission values" do
      permission_params = {
        permissions: {
          can_edit: nil,
          can_add_items: nil,
          can_delete_items: nil,
          receive_notifications: nil
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications")
      expect(json["can_edit"]).to be_falsy
      expect(json["can_add_items"]).to be_falsy
      expect(json["can_delete_items"]).to be_falsy
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should handle empty permission values" do
      permission_params = {
        permissions: {
          can_edit: "",
          can_add_items: "",
          can_delete_items: "",
          receive_notifications: ""
        }
      }
      
      patch "/api/v1/lists/#{list.id}/shares/#{list_share.id}/update_permissions", 
            params: permission_params, 
            headers: owner_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications")
      expect(json["can_edit"]).to be_falsy
      expect(json["can_add_items"]).to be_falsy
      expect(json["can_delete_items"]).to be_falsy
      expect(json["receive_notifications"]).to be_falsy
    end

    it "should handle invalid role values" do
      share_params = {
        email: other_user.email,
        role: "invalid_role"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Validation failed")
    end

    it "should handle very long role values" do
      share_params = {
        email: other_user.email,
        role: "a" * 1000
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Validation failed")
    end

    it "should handle unicode characters in email" do
      unicode_email = "用户@example.com"
      
      share_params = {
        email: unicode_email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(unicode_email)
    end

    it "should handle email with special characters" do
      special_email = "user.name+tag@sub-domain.example.com"
      
      share_params = {
        email: special_email,
        role: "viewer"
      }
      
      post "/api/v1/lists/#{list.id}/shares", params: share_params, headers: owner_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(special_email)
    end
  end

  # Helper method for authentication headers
  def auth_headers(user)
    token = JWT.encode(
      { 
        user_id: user.id, 
        jti: user.jti || SecureRandom.uuid,
        exp: 30.days.from_now.to_i 
      },
      Rails.application.credentials.secret_key_base
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
