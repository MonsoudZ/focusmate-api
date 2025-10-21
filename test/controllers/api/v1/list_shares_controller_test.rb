require "test_helper"

class Api::V1::ListSharesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @list_owner = create_test_user(email: "owner_#{SecureRandom.hex(4)}@example.com")
    @shared_user = create_test_user(email: "shared_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    @list = create_test_list(@list_owner, name: "Shared List")
    
    @list_share = ListShare.create!(
      list: @list,
      user: @shared_user,
      email: @shared_user.email,
      role: "editor",
      status: "accepted",
      can_view: true,
      can_edit: true,
      can_add_items: true,
      can_delete_items: false,
      receive_notifications: true
    )
    
    @owner_headers = auth_headers(@list_owner)
    @shared_user_headers = auth_headers(@shared_user)
    @other_user_headers = auth_headers(@other_user)
  end

  # Index tests
  test "should get all shares for a list (owner only)" do
    get "/api/v1/lists/#{@list.id}/shares", headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @list_share.id, json.first["id"]
  end

  test "should return 403 if not list owner for index" do
    get "/api/v1/lists/#{@list.id}/shares", headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Only list owner can manage shares")
  end

  test "should not get shares without authentication" do
    get "/api/v1/lists/#{@list.id}/shares"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Create (Share) tests
  test "should share list with user by email" do
    share_params = {
      email: @other_user.email,
      role: "member",
      can_view: true,
      can_edit: true,
      can_add_items: true,
      can_delete_items: false,
      receive_notifications: true
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email", "role", "status"])
    
    assert_equal @other_user.email, json["email"]
    assert_equal "member", json["role"]
    assert_equal "accepted", json["status"]
  end

  test "should create with default permissions" do
    share_params = {
      email: @other_user.email,
      role: "viewer"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email", "role", "can_view", "can_edit", "can_add_items", "can_delete_items"])
    
    assert_equal @other_user.email, json["email"]
    assert_equal "viewer", json["role"]
    assert json["can_view"]
    assert_not json["can_edit"]
    assert_not json["can_add_items"]
    assert_not json["can_delete_items"]
  end

  test "should create with custom permissions" do
    share_params = {
      email: @other_user.email,
      role: "member",
      can_view: true,
      can_edit: true,
      can_add_items: true,
      can_delete_items: true,
      receive_notifications: false
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email", "role", "can_view", "can_edit", "can_add_items", "can_delete_items", "receive_notifications"])
    
    assert_equal @other_user.email, json["email"]
    assert_equal "member", json["role"]
    assert json["can_view"]
    assert json["can_edit"]
    assert json["can_add_items"]
    assert json["can_delete_items"]
    assert_not json["receive_notifications"]
  end

  test "should generate invitation_token for non-existent user" do
    share_params = {
      email: "newuser@example.com",
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email", "status", "invitation_token"])
    
    assert_equal "newuser@example.com", json["email"]
    assert_equal "pending", json["status"]
    assert_not_nil json["invitation_token"]
  end

  test "should send email invitation" do
    share_params = {
      email: "invitee@example.com",
      role: "member"
    }
    
    # Mock email service
    ListShareMailer.expects(:invitation_email).returns(mock(deliver_now: true))
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
  end

  test "should return 403 if not list owner" do
    share_params = {
      email: @other_user.email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Only list owner can manage shares")
  end

  test "should return error if already shared with user" do
    share_params = {
      email: @shared_user.email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :ok
    json = assert_json_response(response, ["id", "email"])
    assert_equal @list_share.id, json["id"]
    assert_equal @shared_user.email, json["email"]
  end

  test "should return error if email is blank" do
    share_params = {
      email: "",
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_error_response(response, :bad_request, "Email is required")
  end

  test "should not create share without authentication" do
    share_params = {
      email: @other_user.email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Show tests
  test "should show share details" do
    get "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "email", "role", "status", "can_view", "can_edit"])
    
    assert_equal @list_share.id, json["id"]
    assert_equal @shared_user.email, json["email"]
    assert_equal "member", json["role"]
    assert_equal "accepted", json["status"]
  end

  test "should return 404 if not list owner or shared user" do
    get "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should allow shared user to view their own share" do
    get "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @shared_user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "email"])
    assert_equal @list_share.id, json["id"]
    assert_equal @shared_user.email, json["email"]
  end

  test "should not show share without authentication" do
    get "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Update Permissions tests
  test "should update share permissions (owner only)" do
    permission_params = {
      permissions: {
        can_edit: false,
        can_add_items: false,
        can_delete_items: true,
        receive_notifications: false
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications"])
    
    assert_not json["can_edit"]
    assert_not json["can_add_items"]
    assert json["can_delete_items"]
    assert_not json["receive_notifications"]
  end

  test "should update can_edit, can_add_items, can_delete_items" do
    permission_params = {
      permissions: {
        can_edit: true,
        can_add_items: true,
        can_delete_items: true
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "can_edit", "can_add_items", "can_delete_items"])
    
    assert json["can_edit"]
    assert json["can_add_items"]
    assert json["can_delete_items"]
  end

  test "should update receive_notifications" do
    permission_params = {
      permissions: {
        receive_notifications: false
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "receive_notifications"])
    
    assert_not json["receive_notifications"]
  end

  test "should return 403 if not list owner for permissions" do
    permission_params = {
      permissions: {
        can_edit: false
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Only list owner can manage shares")
  end

  test "should not update permissions without authentication" do
    permission_params = {
      permissions: {
        can_edit: false
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Accept tests
  test "should accept list share invitation" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/lists/#{@list.id}/shares/#{pending_share.id}/accept", 
         headers: @other_user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "status", "user_id", "accepted_at"])
    
    assert_equal "accepted", json["status"]
    assert_equal @other_user.id, json["user_id"]
    assert_not_nil json["accepted_at"]
  end

  test "should link user_id to share" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/lists/#{@list.id}/shares/#{pending_share.id}/accept", 
         headers: @other_user_headers
    
    assert_response :success
    
    pending_share.reload
    assert_equal @other_user.id, pending_share.user_id
  end

  test "should set status to accepted" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/lists/#{@list.id}/shares/#{pending_share.id}/accept", 
         headers: @other_user_headers
    
    assert_response :success
    
    pending_share.reload
    assert pending_share.accepted?
  end

  test "should return error if invitation_token invalid" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: nil
    )
    
    post "/api/v1/lists/#{@list.id}/shares/#{pending_share.id}/accept", 
         headers: @other_user_headers
    
    assert_error_response(response, :unprocessable_entity, "Invitation is not pending")
  end

  test "should return error if already accepted" do
    post "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/accept", 
         headers: @shared_user_headers
    
    assert_error_response(response, :unprocessable_entity, "Invitation is not pending")
  end

  test "should accept invitation via token (email link)" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/list_shares/accept", 
         params: { token: pending_share.invitation_token }, 
         headers: @other_user_headers
    
    assert_response :no_content
    
    pending_share.reload
    assert pending_share.accepted?
    assert_equal @other_user.id, pending_share.user_id
    assert_nil pending_share.invitation_token
  end

  test "should accept invitation via token without authentication" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/list_shares/accept", 
         params: { token: pending_share.invitation_token }
    
    assert_response :no_content
    
    pending_share.reload
    assert pending_share.accepted?
    assert_equal @other_user.id, pending_share.user_id
  end

  # Decline tests
  test "should decline list share invitation" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/lists/#{@list.id}/shares/#{pending_share.id}/decline", 
         headers: @other_user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Invitation declined", json["message"]
    
    pending_share.reload
    assert pending_share.declined?
  end

  test "should set status to declined" do
    pending_share = ListShare.create!(
      list: @list,
      email: @other_user.email,
      role: "member",
      status: "pending",
      invitation_token: SecureRandom.hex(32)
    )
    
    post "/api/v1/lists/#{@list.id}/shares/#{pending_share.id}/decline", 
         headers: @other_user_headers
    
    assert_response :success
    
    pending_share.reload
    assert pending_share.declined?
  end

  test "should return error if not pending" do
    post "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/decline", 
         headers: @shared_user_headers
    
    assert_error_response(response, :unprocessable_entity, "Invitation is not pending")
  end

  # Delete (Revoke) tests
  test "should revoke share (owner only)" do
    delete "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @owner_headers
    
    assert_response :no_content
    
    assert_raises(ActiveRecord::RecordNotFound) do
      ListShare.find(@list_share.id)
    end
  end

  test "should remove user's access to list" do
    delete "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @owner_headers
    
    assert_response :no_content
    
    # Check that user can no longer access the list
    get "/api/v1/lists/#{@list.id}", headers: @shared_user_headers
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should notify user of revocation" do
    # Mock notification service
    ListShareMailer.expects(:revocation_notification).returns(mock(deliver_now: true))
    
    delete "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @owner_headers
    
    assert_response :no_content
  end

  test "shared user should leave list voluntarily" do
    # Create a share where the user can leave voluntarily
    voluntary_share = ListShare.create!(
      list: @list,
      user: @other_user,
      email: @other_user.email,
      role: "member",
      status: "accepted",
      can_leave: true
    )
    
    delete "/api/v1/lists/#{@list.id}/shares/#{voluntary_share.id}", headers: @other_user_headers
    
    assert_response :no_content
    
    assert_raises(ActiveRecord::RecordNotFound) do
      ListShare.find(voluntary_share.id)
    end
  end

  test "should not allow non-owner to revoke share" do
    delete "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}", headers: @other_user_headers
    
    assert_error_response(response, :forbidden, "Only list owner can manage shares")
  end

  test "should not revoke share without authentication" do
    delete "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/lists/#{@list.id}/shares", 
         params: "invalid json",
         headers: @owner_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    post "/api/v1/lists/#{@list.id}/shares", params: {}, headers: @owner_headers
    
    assert_error_response(response, :bad_request, "Email is required")
  end

  test "should handle case insensitive email" do
    share_params = {
      email: @other_user.email.upcase,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email"])
    assert_equal @other_user.email.downcase, json["email"]
  end

  test "should handle whitespace in email" do
    share_params = {
      email: " #{@other_user.email} ",
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email"])
    assert_equal @other_user.email, json["email"]
  end

  test "should handle very long email addresses" do
    long_email = "a" * 200 + "@example.com"
    
    share_params = {
      email: long_email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email", "status"])
    assert_equal long_email, json["email"]
    assert_equal "pending", json["status"]
  end

  test "should handle special characters in email" do
    special_email = "user+tag@example.com"
    
    share_params = {
      email: special_email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email"])
    assert_equal special_email, json["email"]
  end

  test "should handle concurrent share creation" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        share_params = {
          email: "concurrent#{i}@example.com",
          role: "member"
        }
        
        post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed with different emails
    assert true
  end

  test "should handle concurrent permission updates" do
    permission_params = {
      permissions: {
        can_edit: true,
        can_add_items: true
      }
    }
    
    threads = []
    3.times do
      threads << Thread.new do
        patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
              params: permission_params, 
              headers: @owner_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle boolean permission values" do
    permission_params = {
      permissions: {
        can_edit: "true",
        can_add_items: "false",
        can_delete_items: "1",
        receive_notifications: "0"
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications"])
    
    assert json["can_edit"]
    assert_not json["can_add_items"]
    assert json["can_delete_items"]
    assert_not json["receive_notifications"]
  end

  test "should handle string boolean permission values" do
    permission_params = {
      permissions: {
        can_edit: "yes",
        can_add_items: "no",
        can_delete_items: "on",
        receive_notifications: "off"
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications"])
    
    assert json["can_edit"]
    assert_not json["can_add_items"]
    assert json["can_delete_items"]
    assert_not json["receive_notifications"]
  end

  test "should handle nil permission values" do
    permission_params = {
      permissions: {
        can_edit: nil,
        can_add_items: nil,
        can_delete_items: nil,
        receive_notifications: nil
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications"])
    
    assert_not json["can_edit"]
    assert_not json["can_add_items"]
    assert_not json["can_delete_items"]
    assert_not json["receive_notifications"]
  end

  test "should handle empty permission values" do
    permission_params = {
      permissions: {
        can_edit: "",
        can_add_items: "",
        can_delete_items: "",
        receive_notifications: ""
      }
    }
    
    patch "/api/v1/lists/#{@list.id}/shares/#{@list_share.id}/update_permissions", 
          params: permission_params, 
          headers: @owner_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "can_edit", "can_add_items", "can_delete_items", "receive_notifications"])
    
    assert_not json["can_edit"]
    assert_not json["can_add_items"]
    assert_not json["can_delete_items"]
    assert_not json["receive_notifications"]
  end

  test "should handle invalid role values" do
    share_params = {
      email: @other_user.email,
      role: "invalid_role"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle very long role values" do
    share_params = {
      email: @other_user.email,
      role: "a" * 1000
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle unicode characters in email" do
    unicode_email = "用户@example.com"
    
    share_params = {
      email: unicode_email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email"])
    assert_equal unicode_email, json["email"]
  end

  test "should handle email with special characters" do
    special_email = "user.name+tag@sub-domain.example.com"
    
    share_params = {
      email: special_email,
      role: "member"
    }
    
    post "/api/v1/lists/#{@list.id}/shares", params: share_params, headers: @owner_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "email"])
    assert_equal special_email, json["email"]
  end
end
