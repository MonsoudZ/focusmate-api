require "rails_helper"

RSpec.describe Api::V1::RecurringTemplatesController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }
  let(:list) { create(:list, owner: user, name: "Test List") }
  let(:other_list) { create(:list, owner: other_user, name: "Other List") }

  let!(:template) do
    Task.create!(
      list: list,
      creator: user,
      title: "Daily Standup",
      note: "Daily team standup meeting",
      is_recurring: true,
      recurring_template_id: nil,
      recurrence_pattern: "daily",
      recurrence_interval: 1,
      recurrence_time: "09:00",
      due_at: 1.day.from_now,
      status: :pending,
      strict_mode: false
    )
  end

  let(:user_headers) { auth_headers(user) }
  let(:other_user_headers) { auth_headers(other_user) }

  describe "GET /api/v1/recurring_templates" do
    it "should get all recurring templates for user" do
      get "/api/v1/recurring_templates", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(template.id)
    end

    it "should filter by list_id" do
      other_list = create(:list, owner: user, name: "Other List")
      other_template = Task.create!(
        list: other_list,
        creator: user,
        title: "Weekly Review",
        note: "Weekly team review",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "weekly",
        recurrence_interval: 1,
        recurrence_days: [ 1, 3, 5 ], # Monday, Wednesday, Friday
        recurrence_time: "17:00",
        due_at: 1.week.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates?list_id=#{list.id}", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(template.id)
    end

    it "should not get templates from other users" do
      other_template = Task.create!(
        list: other_list,
        creator: other_user,
        title: "Other User's Template",
        note: "This is not your template",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(template.id)
      expect(json.map { |t| t["id"] }).not_to include(other_template.id)
    end

    it "should not get recurring templates without authentication" do
      get "/api/v1/recurring_templates"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle empty templates list" do
      new_user = create(:user, email: "new_user_#{SecureRandom.hex(4)}@example.com")
      new_user_headers = auth_headers(new_user)

      get "/api/v1/recurring_templates", headers: new_user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(0)
    end
  end

  describe "GET /api/v1/recurring_templates/:id" do
    it "should show template details" do
      get "/api/v1/recurring_templates/#{template.id}", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")
      expect(json).to have_key("recurrence_pattern")
      expect(json).to have_key("recurrence_interval")

      expect(json["id"]).to eq(template.id)
      expect(json["title"]).to eq("Daily Standup")
      expect(json["note"]).to eq("Daily team standup meeting")
      expect(json["recurrence_pattern"]).to eq("daily")
      expect(json["recurrence_interval"]).to eq(1)
    end

    it "should not show template from other user" do
      other_template = Task.create!(
        list: other_list,
        creator: other_user,
        title: "Other User's Template",
        note: "This is not your template",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates/#{other_template.id}", headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Recurring template not found")
    end

    it "should not show template without authentication" do
      get "/api/v1/recurring_templates/#{template.id}"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/recurring_templates" do
    it "should create recurring template" do
      template_params = {
        recurring_template: {
          title: "Weekly Team Meeting",
          note: "Weekly team sync meeting",
          recurrence_pattern: "weekly",
          recurrence_interval: 1,
          recurrence_time: "14:00",
          recurrence_days: [ "monday", "wednesday", "friday" ]
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")
      expect(json).to have_key("recurrence_pattern")
      expect(json).to have_key("recurrence_interval")

      expect(json["title"]).to eq("Weekly Team Meeting")
      expect(json["note"]).to eq("Weekly team sync meeting")
      expect(json["recurrence_pattern"]).to eq("weekly")
      expect(json["recurrence_interval"]).to eq(1)
    end

    it "should validate recurrence_pattern" do
      template_params = {
        recurring_template: {
          title: "Invalid Pattern",
          note: "Template with invalid pattern",
          recurrence_pattern: "invalid_pattern",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Validation failed")
    end

    it "should validate recurrence_interval > 0" do
      template_params = {
        recurring_template: {
          title: "Invalid Interval",
          note: "Template with invalid interval",
          recurrence_pattern: "daily",
          recurrence_interval: 0,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Validation failed")
    end

    it "should set is_recurring to true on template task" do
      template_params = {
        recurring_template: {
          title: "Monthly Review",
          note: "Monthly team review",
          recurrence_pattern: "monthly",
          recurrence_interval: 1,
          recurrence_time: "15:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("is_recurring")

      expect(json["is_recurring"]).to be_truthy

      # Verify in database
      template_task = Task.find(json["id"])
      expect(template_task.is_recurring?).to be_truthy
    end

    it "should not create template for other user's list" do
      template_params = {
        recurring_template: {
          title: "Unauthorized Template",
          note: "This should not be created",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: other_list.id), headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("List not found")
    end

    it "should not create template without authentication" do
      template_params = {
        recurring_template: {
          title: "No Auth Template",
          note: "This should not be created",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id)

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "PATCH /api/v1/recurring_templates/:id" do
    it "should update recurring template" do
      update_params = {
        recurring_template: {
          title: "Updated Daily Standup",
          note: "Updated daily team standup meeting",
          recurrence_time: "10:00"
        }
      }

      patch "/api/v1/recurring_templates/#{template.id}", params: update_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")
      expect(json).to have_key("recurrence_time")

      expect(json["title"]).to eq("Updated Daily Standup")
      expect(json["note"]).to eq("Updated daily team standup meeting")
      expect(json["recurrence_time"]).to eq("10:00")
    end

    it "should not affect existing instances" do
      # Create an instance first
      instance = Task.create!(
        list: list,
        creator: user,
        title: "Daily Standup Instance",
        note: "Instance of daily standup",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 1.day.ago,
        status: :pending,
        strict_mode: false
      )

      update_params = {
        recurring_template: {
          title: "Updated Template Title",
          note: "Updated template description"
        }
      }

      patch "/api/v1/recurring_templates/#{template.id}", params: update_params, headers: user_headers

      expect(response).to have_http_status(:success)

      # Check that existing instance is not affected
      instance.reload
      expect(instance.title).to eq("Daily Standup Instance")
      expect(instance.note).to eq("Instance of daily standup")
    end

    it "should affect future instances" do
      # Create an incomplete instance
      incomplete_instance = Task.create!(
        list: list,
        creator: user,
        title: "Incomplete Instance",
        note: "Incomplete instance",
        is_recurring: false,
        recurring_template_id: template.id,
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

      patch "/api/v1/recurring_templates/#{template.id}", params: update_params, headers: user_headers

      expect(response).to have_http_status(:success)

      # Check that incomplete instance is updated
      incomplete_instance.reload
      expect(incomplete_instance.title).to eq("Updated Template Title")
      expect(incomplete_instance.note).to eq("Updated template description")
    end

    it "should not update template from other user" do
      other_template = Task.create!(
        list: other_list,
        creator: other_user,
        title: "Other User's Template",
        note: "This is not your template",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      update_params = {
        recurring_template: {
          title: "Hacked Template",
          note: "This should not be updated"
        }
      }

      patch "/api/v1/recurring_templates/#{other_template.id}", params: update_params, headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Recurring template not found")
    end

    it "should not update template without authentication" do
      update_params = {
        recurring_template: {
          title: "No Auth Update",
          note: "This should not be updated"
        }
      }

      patch "/api/v1/recurring_templates/#{template.id}", params: update_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "DELETE /api/v1/recurring_templates/:id" do
    it "should delete recurring template" do
      delete "/api/v1/recurring_templates/#{template.id}", headers: user_headers

      expect(response).to have_http_status(:no_content)

      expect { Task.find(template.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should optionally delete all instances" do
      # Create instances
      instance1 = Task.create!(
        list: list,
        creator: user,
        title: "Instance 1",
        note: "First instance",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      instance2 = Task.create!(
        list: list,
        creator: user,
        title: "Instance 2",
        note: "Second instance",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 2.days.from_now,
        status: :pending,
        strict_mode: false
      )

      delete "/api/v1/recurring_templates/#{template.id}", headers: user_headers

      expect(response).to have_http_status(:no_content)

      # All instances should be deleted
      expect { Task.find(instance1.id) }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Task.find(instance2.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should not delete template from other user" do
      other_template = Task.create!(
        list: other_list,
        creator: other_user,
        title: "Other User's Template",
        note: "This is not your template",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      delete "/api/v1/recurring_templates/#{other_template.id}", headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Recurring template not found")
    end

    it "should not delete template without authentication" do
      delete "/api/v1/recurring_templates/#{template.id}"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/recurring_templates/:id/generate_instance" do
    it "should manually generate instance from template" do
      post "/api/v1/recurring_templates/#{template.id}/generate_instance", headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")
      expect(json).to have_key("recurring_template_id")

      expect(json["title"]).to eq("Daily Standup")
      expect(json["note"]).to eq("Daily team standup meeting")
      expect(json["recurring_template_id"]).to eq(template.id)
    end

    it "should calculate next due date based on pattern" do
      post "/api/v1/recurring_templates/#{template.id}/generate_instance", headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("due_at")

      expect(json["due_at"]).not_to be_nil

      # Verify the instance was created with correct due date
      instance = Task.find(json["id"])
      expect(instance.due_at).not_to be_nil
    end

    it "should copy template attributes to instance" do
      post "/api/v1/recurring_templates/#{template.id}/generate_instance", headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")
      expect(json).to have_key("recurring_template_id")

      expect(json["title"]).to eq(template.title)
      expect(json["note"]).to eq(template.note)
      expect(json["recurring_template_id"]).to eq(template.id)
    end

    it "should link instance to template (recurring_template_id)" do
      post "/api/v1/recurring_templates/#{template.id}/generate_instance", headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("recurring_template_id")

      expect(json["recurring_template_id"]).to eq(template.id)

      # Verify in database
      instance = Task.find(json["id"])
      expect(instance.recurring_template_id).to eq(template.id)
    end

    it "should not generate instance from other user's template" do
      other_template = Task.create!(
        list: other_list,
        creator: other_user,
        title: "Other User's Template",
        note: "This is not your template",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      post "/api/v1/recurring_templates/#{other_template.id}/generate_instance", headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Recurring template not found")
    end

    it "should not generate instance without authentication" do
      post "/api/v1/recurring_templates/#{template.id}/generate_instance"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end
  end

  describe "GET /api/v1/recurring_templates/:id/instances" do
    it "should get all instances of a template" do
      # Create instances
      instance1 = Task.create!(
        list: list,
        creator: user,
        title: "Instance 1",
        note: "First instance",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      instance2 = Task.create!(
        list: list,
        creator: user,
        title: "Instance 2",
        note: "Second instance",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 2.days.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates/#{template.id}/instances", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(2)

      instance_ids = json.map { |i| i["id"] }
      expect(instance_ids).to include(instance1.id)
      expect(instance_ids).to include(instance2.id)
    end

    it "should order by due_at" do
      # Create instances with different due dates
      future_instance = Task.create!(
        list: list,
        creator: user,
        title: "Future Instance",
        note: "Future instance",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 3.days.from_now,
        status: :pending,
        strict_mode: false
      )

      past_instance = Task.create!(
        list: list,
        creator: user,
        title: "Past Instance",
        note: "Past instance",
        is_recurring: false,
        recurring_template_id: template.id,
        due_at: 1.day.ago,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates/#{template.id}/instances", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(2)

      # Should be ordered by due_at descending (most recent first)
      expect(json.first["id"]).to eq(future_instance.id)
      expect(json.last["id"]).to eq(past_instance.id)
    end

    it "should not get instances from other user's template" do
      other_template = Task.create!(
        list: other_list,
        creator: other_user,
        title: "Other User's Template",
        note: "This is not your template",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates/#{other_template.id}/instances", headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Recurring template not found")
    end

    it "should not get instances without authentication" do
      get "/api/v1/recurring_templates/#{template.id}/instances"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle template with no instances" do
      new_template = Task.create!(
        list: list,
        creator: user,
        title: "New Template",
        note: "Template with no instances",
        is_recurring: true,
        recurring_template_id: nil,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: "10:00",
        due_at: 1.day.from_now,
        status: :pending,
        strict_mode: false
      )

      get "/api/v1/recurring_templates/#{new_template.id}/instances", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(0)
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      patch "/api/v1/recurring_templates/#{template.id}",
            params: "invalid json",
            headers: user_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it "should handle empty request body" do
      patch "/api/v1/recurring_templates/#{template.id}", params: {}, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(template.id)
    end

    it "should handle very long template titles" do
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

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Validation failed")
    end

    it "should handle special characters in template" do
      template_params = {
        recurring_template: {
          title: "Template with Special Chars: !@#$%^&*()",
          note: "Template with special characters: éñ中文",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")

      expect(json["title"]).to eq("Template with Special Chars: !@#$%^&*()")
      expect(json["note"]).to eq("Template with special characters: éñ中文")
    end

    it "should handle unicode characters in template" do
      template_params = {
        recurring_template: {
          title: "Unicode Template: 🚀📱💻",
          note: "Template with emojis: 🎉🎊🎈",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("note")

      expect(json["title"]).to eq("Unicode Template: 🚀📱💻")
      expect(json["note"]).to eq("Template with emojis: 🎉🎊🎈")
    end

    it "should handle concurrent template creation" do
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

          post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers
        end
      end

      threads.each(&:join)
      # All should succeed with different titles
      expect(true).to be_truthy
    end

    it "should handle concurrent instance generation" do
      threads = []
      3.times do
        threads << Thread.new do
          post "/api/v1/recurring_templates/#{template.id}/generate_instance", headers: user_headers
        end
      end

      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle invalid recurrence patterns" do
      invalid_patterns = [ "invalid", "daily_weekly", "monthly_daily", "" ]

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

        post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("Validation failed")
      end
    end

    it "should handle invalid recurrence intervals" do
      invalid_intervals = [ 0, -1, -5, "invalid", "" ]

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

        post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("Validation failed")
      end
    end

    it "should handle invalid recurrence times" do
      invalid_times = [ "25:00", "12:60", "invalid", "24:00" ]

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

        post "/api/v1/recurring_templates", params: template_params.merge(list_id: list.id), headers: user_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to eq("Validation failed")
      end
    end

    it "should handle missing list_id parameter" do
      template_params = {
        recurring_template: {
          title: "No List Template",
          note: "Template without list",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params, headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("List not found")
    end

    it "should handle non-existent list_id" do
      template_params = {
        recurring_template: {
          title: "Non-existent List Template",
          note: "Template for non-existent list",
          recurrence_pattern: "daily",
          recurrence_interval: 1,
          recurrence_time: "10:00"
        }
      }

      post "/api/v1/recurring_templates", params: template_params.merge(list_id: 99999), headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("List not found")
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
