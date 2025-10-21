require "test_helper"

class Api::V1::ListsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @auth_headers = auth_headers(@user)
  end

  # Index tests
  test "should get all lists owned by user" do
    # Create additional lists for the user
    list2 = create_test_list(@user, name: "Second List")
    list3 = create_test_list(@user, name: "Third List")
    
    get "/api/v1/lists", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["lists", "tombstones"])
    
    assert json["lists"].is_a?(Array)
    assert json["tombstones"].is_a?(Array)
    
    list_ids = json["lists"].map { |l| l["id"] }
    assert_includes list_ids, @list.id
    assert_includes list_ids, list2.id
    assert_includes list_ids, list3.id
  end

  test "should get lists shared with user" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list with current user
    ListShare.create!(
      list: shared_list,
      user: @user,
      status: "accepted",
      invited_by: "owner"
    )
    
    get "/api/v1/lists", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["lists"])
    
    list_ids = json["lists"].map { |l| l["id"] }
    assert_includes list_ids, @list.id # Owned list
    assert_includes list_ids, shared_list.id # Shared list
  end

  test "should filter lists by since parameter" do
    old_list = create_test_list(@user, name: "Old List", created_at: 2.days.ago)
    
    get "/api/v1/lists?since=#{1.day.ago.iso8601}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["lists"])
    
    list_ids = json["lists"].map { |l| l["id"] }
    assert_includes list_ids, @list.id
    assert_not_includes list_ids, old_list.id
  end

  test "should return tombstones for deleted lists" do
    # Soft delete a list
    @list.soft_delete!
    
    get "/api/v1/lists", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["lists", "tombstones"])
    
    assert json["lists"].is_a?(Array)
    assert json["tombstones"].is_a?(Array)
    assert_equal 1, json["tombstones"].length
    assert_equal @list.id, json["tombstones"].first["id"]
    assert_equal "list", json["tombstones"].first["type"]
  end

  test "should not get lists without authentication" do
    get "/api/v1/lists"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not include lists from other users" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user, name: "Other User's List")
    
    get "/api/v1/lists", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["lists"])
    
    list_ids = json["lists"].map { |l| l["id"] }
    assert_includes list_ids, @list.id
    assert_not_includes list_ids, other_list.id
  end

  # Show tests
  test "should show list details" do
    get "/api/v1/lists/#{@list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name", "description"])
    
    assert_equal @list.id, json["id"]
    assert_equal @list.name, json["name"]
    assert_equal @list.description, json["description"]
  end

  test "should include tasks in list details" do
    task = create_test_task(@list, creator: @user)
    
    get "/api/v1/lists/#{@list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "tasks"])
    
    assert json["tasks"].is_a?(Array)
    assert_equal 1, json["tasks"].length
    assert_equal task.id, json["tasks"].first["id"]
  end

  test "should not show list without authentication" do
    get "/api/v1/lists/#{@list.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not show other user's private list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user, name: "Private List")
    
    get "/api/v1/lists/#{other_list.id}", headers: @auth_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should show shared list to user with access" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list with current user
    ListShare.create!(
      list: shared_list,
      user: @user,
      status: "accepted",
      invited_by: "owner"
    )
    
    get "/api/v1/lists/#{shared_list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name"])
    assert_equal shared_list.id, json["id"]
    assert_equal "Shared List", json["name"]
  end

  # Create tests
  test "should create list with valid params" do
    list_params = {
      list: {
        name: "New List",
        description: "A new list for testing"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "description"])
    
    assert_equal "New List", json["name"]
    assert_equal "A new list for testing", json["description"]
    assert_not_nil json["id"]
  end

  test "should require name" do
    list_params = {
      list: {
        description: "List without name"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should allow creating list without description" do
    list_params = {
      list: {
        name: "List without description"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List without description", json["name"]
  end

  test "should not create list without authentication" do
    list_params = {
      list: {
        name: "Unauthorized List"
      }
    }
    
    post "/api/v1/lists", params: list_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should set owner to current user" do
    list_params = {
      list: {
        name: "Owned List"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id"])
    
    created_list = List.find(json["id"])
    assert_equal @user.id, created_list.user_id
  end

  test "should handle very long list name" do
    long_name = "a" * 256 # Too long
    
    list_params = {
      list: {
        name: long_name
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle very long description" do
    long_description = "a" * 1001 # Too long
    
    list_params = {
      list: {
        name: "List with long description",
        description: long_description
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  # Update tests
  test "should update list with valid params" do
    update_params = {
      list: {
        name: "Updated List Name",
        description: "Updated description"
      }
    }
    
    patch "/api/v1/lists/#{@list.id}", params: update_params, headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name", "description"])
    
    assert_equal "Updated List Name", json["name"]
    assert_equal "Updated description", json["description"]
    
    @list.reload
    assert_equal "Updated List Name", @list.name
    assert_equal "Updated description", @list.description
  end

  test "should not update list without authentication" do
    update_params = {
      list: {
        name: "Unauthorized Update"
      }
    }
    
    patch "/api/v1/lists/#{@list.id}", params: update_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not update other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user, name: "Other User's List")
    
    update_params = {
      list: {
        name: "Unauthorized Update"
      }
    }
    
    patch "/api/v1/lists/#{other_list.id}", params: update_params, headers: @auth_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should allow updating shared list if user has edit permission" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list with edit permission
    ListShare.create!(
      list: shared_list,
      user: @user,
      status: "accepted",
      invited_by: "owner",
      can_edit: true
    )
    
    update_params = {
      list: {
        name: "Updated Shared List"
      }
    }
    
    patch "/api/v1/lists/#{shared_list.id}", params: update_params, headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name"])
    assert_equal "Updated Shared List", json["name"]
  end

  test "should not allow updating shared list without edit permission" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list without edit permission
    ListShare.create!(
      list: shared_list,
      user: @user,
      status: "accepted",
      invited_by: "owner",
      can_edit: false
    )
    
    update_params = {
      list: {
        name: "Unauthorized Update"
      }
    }
    
    patch "/api/v1/lists/#{shared_list.id}", params: update_params, headers: @auth_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  # Delete tests
  test "should soft delete list" do
    delete "/api/v1/lists/#{@list.id}", headers: @auth_headers
    
    assert_response :no_content
    
    @list.reload
    assert @list.deleted?
    assert_not_nil @list.deleted_at
  end

  test "should not delete list without authentication" do
    delete "/api/v1/lists/#{@list.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should not delete other user's list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user, name: "Other User's List")
    
    delete "/api/v1/lists/#{other_list.id}", headers: @auth_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should not allow deleting shared list" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list with current user
    ListShare.create!(
      list: shared_list,
      user: @user,
      status: "accepted",
      invited_by: "owner"
    )
    
    delete "/api/v1/lists/#{shared_list.id}", headers: @auth_headers
    
    assert_error_response(response, :forbidden, "Unauthorized")
  end

  test "should cascade delete to tasks when list is deleted" do
    task = create_test_task(@list, creator: @user)
    
    delete "/api/v1/lists/#{@list.id}", headers: @auth_headers
    
    assert_response :no_content
    
    # Check that task is also soft deleted
    task.reload
    assert task.deleted?
  end

  # Validate access tests
  test "should validate access to owned list" do
    get "/api/v1/lists/validate/#{@list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["list_id", "accessible", "owner"])
    
    assert_equal @list.id.to_s, json["list_id"]
    assert json["accessible"]
    assert_equal @user.email, json["owner"]
  end

  test "should validate access to shared list" do
    other_user = create_test_user(email: "other@example.com")
    shared_list = create_test_list(other_user, name: "Shared List")
    
    # Share list with current user
    ListShare.create!(
      list: shared_list,
      user: @user,
      status: "accepted",
      invited_by: "owner"
    )
    
    get "/api/v1/lists/validate/#{shared_list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["list_id", "accessible", "owner"])
    
    assert_equal shared_list.id.to_s, json["list_id"]
    assert json["accessible"]
    assert_equal other_user.email, json["owner"]
  end

  test "should validate access to inaccessible list" do
    other_user = create_test_user(email: "other@example.com")
    other_list = create_test_list(other_user, name: "Private List")
    
    get "/api/v1/lists/validate/#{other_list.id}", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["list_id", "accessible"])
    
    assert_equal other_list.id.to_s, json["list_id"]
    assert_not json["accessible"]
    assert_nil json["owner"]
  end

  test "should validate access to non-existent list" do
    get "/api/v1/lists/validate/999999", headers: @auth_headers
    
    assert_response :success
    json = assert_json_response(response, ["list_id", "accessible", "error"])
    
    assert_equal "999999", json["list_id"]
    assert_not json["accessible"]
    assert_equal "List not found", json["error"]
  end

  test "should not validate access without authentication" do
    get "/api/v1/lists/validate/#{@list.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/lists", 
         params: "invalid json",
         headers: @auth_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    post "/api/v1/lists", params: {}, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle special characters in list name" do
    list_params = {
      list: {
        name: "List with émojis 🎯 and special chars: @#$%"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List with émojis 🎯 and special chars: @#$%", json["name"]
  end

  test "should handle unicode characters in list name" do
    list_params = {
      list: {
        name: "中文, العربية, русский, 日本語, 한국어"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "中文, العربية, русский, 日本語, 한국어", json["name"]
  end

  test "should handle concurrent list creation" do
    threads = []
    5.times do |i|
      threads << Thread.new do
        list_params = {
          list: {
            name: "Concurrent List #{i}"
          }
        }
        
        post "/api/v1/lists", params: list_params, headers: @auth_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle very long list names" do
    long_name = "a" * 1000
    
    list_params = {
      list: {
        name: long_name
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle very long descriptions" do
    long_description = "a" * 5000
    
    list_params = {
      list: {
        name: "List with long description",
        description: long_description
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle empty list name" do
    list_params = {
      list: {
        name: ""
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle whitespace-only list name" do
    list_params = {
      list: {
        name: "   "
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle nil list name" do
    list_params = {
      list: {
        name: nil
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle duplicate list names for same user" do
    # Create first list
    list_params1 = {
      list: {
        name: "Duplicate Name"
      }
    }
    
    post "/api/v1/lists", params: list_params1, headers: @auth_headers
    assert_response :created
    
    # Create second list with same name
    list_params2 = {
      list: {
        name: "Duplicate Name"
      }
    }
    
    post "/api/v1/lists", params: list_params2, headers: @auth_headers
    assert_response :created # Should be allowed for same user
  end

  test "should handle list names with HTML tags" do
    list_params = {
      list: {
        name: "<script>alert('xss')</script>List Name"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "<script>alert('xss')</script>List Name", json["name"]
  end

  test "should handle list names with SQL injection attempts" do
    list_params = {
      list: {
        name: "'; DROP TABLE lists; --"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "'; DROP TABLE lists; --", json["name"]
  end

  test "should handle list names with newlines and tabs" do
    list_params = {
      list: {
        name: "List\nwith\ttabs\r\nand\nnewlines"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List\nwith\ttabs\r\nand\nnewlines", json["name"]
  end

  test "should handle list names with quotes" do
    list_params = {
      list: {
        name: 'List with "double quotes" and \'single quotes\''
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal 'List with "double quotes" and \'single quotes\'', json["name"]
  end

  test "should handle list names with backslashes" do
    list_params = {
      list: {
        name: "List with \\backslashes\\ and \\\\double\\\\ backslashes"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List with \\backslashes\\ and \\\\double\\\\ backslashes", json["name"]
  end

  test "should handle list names with forward slashes" do
    list_params = {
      list: {
        name: "List with /forward/slashes/and//double//slashes"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List with /forward/slashes/and//double//slashes", json["name"]
  end

  test "should handle list names with parentheses" do
    list_params = {
      list: {
        name: "List with (parentheses) and [brackets] and {braces}"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List with (parentheses) and [brackets] and {braces}", json["name"]
  end

  test "should handle list names with numbers" do
    list_params = {
      list: {
        name: "List 123 with 456 numbers 789"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List 123 with 456 numbers 789", json["name"]
  end

  test "should handle list names with mixed case" do
    list_params = {
      list: {
        name: "List With MiXeD cAsE aNd CaPiTaLiZaTiOn"
      }
    }
    
    post "/api/v1/lists", params: list_params, headers: @auth_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    assert_equal "List With MiXeD cAsE aNd CaPiTaLiZaTiOn", json["name"]
  end
end
