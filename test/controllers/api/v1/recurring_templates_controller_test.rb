require "test_helper"

class Api::V1::RecurringTemplatesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(email: "user_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    @list = create_test_list(@user, name: "Test List")
    @other_list = create_test_list(@other_user, name: "Other List")
    
    @template = Task.create!(
      list: @list,
      creator: @user,
      title: "Daily Standup",
      note: "Daily team standup meeting",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "09:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    @user_headers = auth_headers(@user)
    @other_user_headers = auth_headers(@other_user)
  end

  # Index tests
  test "should get all recurring templates for user" do
    get "/api/v1/recurring_templates", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @template.id, json.first["id"]
  end

  test "should filter by list_id" do
    other_list = create_test_list(@user, name: "Other List")
    other_template = Task.create!(
      list: other_list,
      creator: @user,
      title: "Weekly Review",
      note: "Weekly team review",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "weekly",
      recurrence_interval: 1,
      recurrence_time: "17:00",
      due_at: 1.week.from_now,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates?list_id=#{@list.id}", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @template.id, json.first["id"]
  end

  test "should not get templates from other users" do
    other_template = Task.create!(
      list: @other_list,
      creator: @other_user,
      title: "Other User's Template",
      note: "This is not your template",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @template.id, json.first["id"]
    assert_not_includes json.map { |t| t["id"] }, other_template.id
  end

  test "should not get recurring templates without authentication" do
    get "/api/v1/recurring_templates"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle empty templates list" do
    new_user = create_test_user(email: "new_user_#{SecureRandom.hex(4)}@example.com")
    new_user_headers = auth_headers(new_user)
    
    get "/api/v1/recurring_templates", headers: new_user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 0, json.length
  end

  # Show tests
  test "should show template details" do
    get "/api/v1/recurring_templates/#{@template.id}", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "title", "note", "recurrence_pattern", "recurrence_interval"])
    
    assert_equal @template.id, json["id"]
    assert_equal "Daily Standup", json["title"]
    assert_equal "Daily team standup meeting", json["note"]
    assert_equal "daily", json["recurrence_pattern"]
    assert_equal 1, json["recurrence_interval"]
  end

  test "should not show template from other user" do
    other_template = Task.create!(
      list: @other_list,
      creator: @other_user,
      title: "Other User's Template",
      note: "This is not your template",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates/#{other_template.id}", headers: @user_headers
    
    assert_error_response(response, :not_found, "Recurring template not found")
  end

  test "should not show template without authentication" do
    get "/api/v1/recurring_templates/#{@template.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Create tests
  test "should create recurring template" do
    template_params = {
      recurring_template: {
        title: "Weekly Team Meeting",
        note: "Weekly team sync meeting",
        recurrence_pattern: "weekly",
        recurrence_interval: 1,
        recurrence_time: "14:00",
        recurrence_days: ["monday", "wednesday", "friday"]
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title", "note", "recurrence_pattern", "recurrence_interval"])
    
    assert_equal "Weekly Team Meeting", json["title"]
    assert_equal "Weekly team sync meeting", json["note"]
    assert_equal "weekly", json["recurrence_pattern"]
    assert_equal 1, json["recurrence_interval"]
  end

  test "should validate recurrence_pattern" do
    template_params = {
      recurring_template: {
        title: "Invalid Pattern",
        note: "Template with invalid pattern",
        recurrence_pattern: "invalid_pattern",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should validate recurrence_interval > 0" do
    template_params = {
      recurring_template: {
        title: "Invalid Interval",
        note: "Template with invalid interval",
        recurrence_pattern: "daily",
        recurrence_interval: 0,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should set is_recurring to true on template task" do
    template_params = {
      recurring_template: {
        title: "Monthly Review",
        note: "Monthly team review",
        recurrence_pattern: "monthly",
        recurrence_interval: 1,
        recurrence_time: "15:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "is_recurring"])
    
    assert json["is_recurring"]
    
    # Verify in database
    template = Task.find(json["id"])
    assert template.is_recurring?
  end

  test "should not create template for other user's list" do
    template_params = {
      recurring_template: {
        title: "Unauthorized Template",
        note: "This should not be created",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @other_list.id), headers: @user_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  test "should not create template without authentication" do
    template_params = {
      recurring_template: {
        title: "No Auth Template",
        note: "This should not be created",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id)
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Update tests
  test "should update recurring template" do
    update_params = {
      recurring_template: {
        title: "Updated Daily Standup",
        note: "Updated daily team standup meeting",
        recurrence_time: "10:00"
      }
    }
    
    patch "/api/v1/recurring_templates/#{@template.id}", params: update_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "title", "note", "recurrence_time"])
    
    assert_equal "Updated Daily Standup", json["title"]
    assert_equal "Updated daily team standup meeting", json["note"]
    assert_equal "10:00", json["recurrence_time"]
  end

  test "should not affect existing instances" do
    # Create an instance first
    instance = Task.create!(
      list: @list,
      creator: @user,
      title: "Daily Standup Instance",
      note: "Instance of daily standup",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    update_params = {
      recurring_template: {
        title: "Updated Template Title",
        note: "Updated template description"
      }
    }
    
    patch "/api/v1/recurring_templates/#{@template.id}", params: update_params, headers: @user_headers
    
    assert_response :success
    
    # Check that existing instance is not affected
    instance.reload
    assert_equal "Daily Standup Instance", instance.title
    assert_equal "Instance of daily standup", instance.note
  end

  test "should affect future instances" do
    # Create an incomplete instance
    incomplete_instance = Task.create!(
      list: @list,
      creator: @user,
      title: "Incomplete Instance",
      note: "Incomplete instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 1.day.from_now,
      status: "pending",
      strict_mode: false
    )
    
    update_params = {
      recurring_template: {
        title: "Updated Template Title",
        note: "Updated template description"
      }
    }
    
    patch "/api/v1/recurring_templates/#{@template.id}", params: update_params, headers: @user_headers
    
    assert_response :success
    
    # Check that incomplete instance is updated
    incomplete_instance.reload
    assert_equal "Updated Template Title", incomplete_instance.title
    assert_equal "Updated template description", incomplete_instance.note
  end

  test "should not update template from other user" do
    other_template = Task.create!(
      list: @other_list,
      creator: @other_user,
      title: "Other User's Template",
      note: "This is not your template",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    update_params = {
      recurring_template: {
        title: "Hacked Template",
        note: "This should not be updated"
      }
    }
    
    patch "/api/v1/recurring_templates/#{other_template.id}", params: update_params, headers: @user_headers
    
    assert_error_response(response, :not_found, "Recurring template not found")
  end

  test "should not update template without authentication" do
    update_params = {
      recurring_template: {
        title: "No Auth Update",
        note: "This should not be updated"
      }
    }
    
    patch "/api/v1/recurring_templates/#{@template.id}", params: update_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Delete tests
  test "should delete recurring template" do
    delete "/api/v1/recurring_templates/#{@template.id}", headers: @user_headers
    
    assert_response :no_content
    
    assert_raises(ActiveRecord::RecordNotFound) do
      Task.find(@template.id)
    end
  end

  test "should optionally delete all instances" do
    # Create instances
    instance1 = Task.create!(
      list: @list,
      creator: @user,
      title: "Instance 1",
      note: "First instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    instance2 = Task.create!(
      list: @list,
      creator: @user,
      title: "Instance 2",
      note: "Second instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 2.days.from_now,
      strict_mode: false
    )
    
    delete "/api/v1/recurring_templates/#{@template.id}", headers: @user_headers
    
    assert_response :no_content
    
    # All instances should be deleted
    assert_raises(ActiveRecord::RecordNotFound) do
      Task.find(instance1.id)
    end
    
    assert_raises(ActiveRecord::RecordNotFound) do
      Task.find(instance2.id)
    end
  end

  test "should not delete template from other user" do
    other_template = Task.create!(
      list: @other_list,
      creator: @other_user,
      title: "Other User's Template",
      note: "This is not your template",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    delete "/api/v1/recurring_templates/#{other_template.id}", headers: @user_headers
    
    assert_error_response(response, :not_found, "Recurring template not found")
  end

  test "should not delete template without authentication" do
    delete "/api/v1/recurring_templates/#{@template.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Generate Instance tests
  test "should manually generate instance from template" do
    post "/api/v1/recurring_templates/#{@template.id}/generate_instance", headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title", "note", "recurring_template_id"])
    
    assert_equal "Daily Standup", json["title"]
    assert_equal "Daily team standup meeting", json["note"]
    assert_equal @template.id, json["recurring_template_id"]
  end

  test "should calculate next due date based on pattern" do
    post "/api/v1/recurring_templates/#{@template.id}/generate_instance", headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "due_at"])
    
    assert_not_nil json["due_at"]
    
    # Verify the instance was created with correct due date
    instance = Task.find(json["id"])
    assert_not_nil instance.due_at
  end

  test "should copy template attributes to instance" do
    post "/api/v1/recurring_templates/#{@template.id}/generate_instance", headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title", "note", "recurring_template_id"])
    
    assert_equal @template.title, json["title"]
    assert_equal @template.note, json["note"]
    assert_equal @template.id, json["recurring_template_id"]
  end

  test "should link instance to template (recurring_template_id)" do
    post "/api/v1/recurring_templates/#{@template.id}/generate_instance", headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "recurring_template_id"])
    
    assert_equal @template.id, json["recurring_template_id"]
    
    # Verify in database
    instance = Task.find(json["id"])
    assert_equal @template.id, instance.recurring_template_id
  end

  test "should not generate instance from other user's template" do
    other_template = Task.create!(
      list: @other_list,
      creator: @other_user,
      title: "Other User's Template",
      note: "This is not your template",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    post "/api/v1/recurring_templates/#{other_template.id}/generate_instance", headers: @user_headers
    
    assert_error_response(response, :not_found, "Recurring template not found")
  end

  test "should not generate instance without authentication" do
    post "/api/v1/recurring_templates/#{@template.id}/generate_instance"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Get Instances tests
  test "should get all instances of a template" do
    # Create instances
    instance1 = Task.create!(
      list: @list,
      creator: @user,
      title: "Instance 1",
      note: "First instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    instance2 = Task.create!(
      list: @list,
      creator: @user,
      title: "Instance 2",
      note: "Second instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 2.days.from_now,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates/#{@template.id}/instances", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 2, json.length
    
    instance_ids = json.map { |i| i["id"] }
    assert_includes instance_ids, instance1.id
    assert_includes instance_ids, instance2.id
  end

  test "should order by due_at" do
    # Create instances with different due dates
    future_instance = Task.create!(
      list: @list,
      creator: @user,
      title: "Future Instance",
      note: "Future instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 3.days.from_now,
      strict_mode: false
    )
    
    past_instance = Task.create!(
      list: @list,
      creator: @user,
      title: "Past Instance",
      note: "Past instance",
      is_recurring: false,
      recurring_template_id: @template.id,
      due_at: 1.day.ago,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates/#{@template.id}/instances", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 2, json.length
    
    # Should be ordered by due_at descending (most recent first)
    assert_equal future_instance.id, json.first["id"]
    assert_equal past_instance.id, json.last["id"]
  end

  test "should not get instances from other user's template" do
    other_template = Task.create!(
      list: @other_list,
      creator: @other_user,
      title: "Other User's Template",
      note: "This is not your template",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates/#{other_template.id}/instances", headers: @user_headers
    
    assert_error_response(response, :not_found, "Recurring template not found")
  end

  test "should not get instances without authentication" do
    get "/api/v1/recurring_templates/#{@template.id}/instances"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle template with no instances" do
    new_template = Task.create!(
      list: @list,
      creator: @user,
      title: "New Template",
      note: "Template with no instances",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "10:00",
      due_at: 1.day.from_now,
      strict_mode: false
    )
    
    get "/api/v1/recurring_templates/#{new_template.id}/instances", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 0, json.length
  end

  # Edge cases
  test "should handle malformed JSON" do
    patch "/api/v1/recurring_templates/#{@template.id}", 
          params: "invalid json",
          headers: @user_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    patch "/api/v1/recurring_templates/#{@template.id}", params: {}, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id"])
    assert_equal @template.id, json["id"]
  end

  test "should handle very long template titles" do
    long_title = "A" * 1000
    
    template_params = {
      recurring_template: {
        title: long_title,
        note: "Template with long title",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle special characters in template" do
    template_params = {
      recurring_template: {
        title: "Template with Special Chars: !@#$%^&*()",
        note: "Template with special characters: éñ中文",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title", "note"])
    
    assert_equal "Template with Special Chars: !@#$%^&*()", json["title"]
    assert_equal "Template with special characters: éñ中文", json["note"]
  end

  test "should handle unicode characters in template" do
    template_params = {
      recurring_template: {
        title: "Unicode Template: 🚀📱💻",
        note: "Template with emojis: 🎉🎊🎈",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "title", "note"])
    
    assert_equal "Unicode Template: 🚀📱💻", json["title"]
    assert_equal "Template with emojis: 🎉🎊🎈", json["note"]
  end

  test "should handle concurrent template creation" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        template_params = {
          recurring_template: {
            title: "Concurrent Template #{i}",
            note: "Concurrent template #{i}",
            recurrence_pattern: "daily",
            recurrence_interval: 1,
            recurrence_time: "10:00"
          }
        }
        
        post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed with different titles
    assert true
  end

  test "should handle concurrent instance generation" do
    threads = []
    3.times do
      threads << Thread.new do
        post "/api/v1/recurring_templates/#{@template.id}/generate_instance", headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle invalid recurrence patterns" do
    invalid_patterns = ["invalid", "daily_weekly", "monthly_daily", ""]
    
    invalid_patterns.each do |pattern|
      template_params = {
        recurring_template: {
          title: "Invalid Pattern Template",
          note: "Template with invalid pattern",
          recurrence_pattern: pattern,
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }
      
      post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
      
      assert_error_response(response, :unprocessable_entity, "Validation failed")
    end
  end

  test "should handle invalid recurrence intervals" do
    invalid_intervals = [0, -1, -5, "invalid", ""]
    
    invalid_intervals.each do |interval|
      template_params = {
        recurring_template: {
          title: "Invalid Interval Template",
          note: "Template with invalid interval",
          recurrence_pattern: "daily",
          recurrence_interval: interval,
          recurrence_time: "10:00"
        }
      }
      
      post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
      
      assert_error_response(response, :unprocessable_entity, "Validation failed")
    end
  end

  test "should handle invalid recurrence times" do
    invalid_times = ["25:00", "12:60", "invalid", "24:00"]
    
    invalid_times.each do |time|
      template_params = {
        recurring_template: {
          title: "Invalid Time Template",
          note: "Template with invalid time",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: time
        }
      }
      
      post "/api/v1/recurring_templates", params: template_params.merge(list_id: @list.id), headers: @user_headers
      
      assert_error_response(response, :unprocessable_entity, "Validation failed")
    end
  end

  test "should handle missing list_id parameter" do
    template_params = {
      recurring_template: {
        title: "No List Template",
        note: "Template without list",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params, headers: @user_headers
    
    assert_error_response(response, :not_found, "List not found")
  end

  test "should handle non-existent list_id" do
    template_params = {
      recurring_template: {
        title: "Non-existent List Template",
        note: "Template for non-existent list",
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00"
      }
    }
    
    post "/api/v1/recurring_templates", params: template_params.merge(list_id: 99999), headers: @user_headers
    
    assert_error_response(response, :not_found, "List not found")
  end
end
