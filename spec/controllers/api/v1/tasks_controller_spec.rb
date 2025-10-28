# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TasksController, type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.credentials.secret_key_base)}" } }

  describe 'GET /api/v1/lists/:list_id/tasks' do
    it 'should get tasks for list' do
      # Create user manually
      test_user = User.create!(
        email: "test_#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "client"
      )

      # Create list manually
      test_list = List.create!(
        name: "Test List",
        description: "A test list",
        user: test_user
      )

      # Create task manually
      test_task = Task.create!(
        title: "Test Task",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false,
        list: test_list,
        creator: test_user
      )

      # Create auth headers
      token = JWT.encode({ user_id: test_user.id, exp: 24.hours.from_now.to_i }, Rails.application.credentials.secret_key_base)
      test_auth_headers = { 'Authorization' => "Bearer #{token}" }

      get "/api/v1/lists/#{test_list.id}/tasks", headers: test_auth_headers

      if response.status == 500
        puts "Response body: #{response.body}"
      end

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json).to have_key("tombstones")
      expect(json["tasks"]).to be_a(Array)
      expect(json["tombstones"]).to be_a(Array)
    end

    it 'should get all tasks across lists' do
      other_list = create(:list, user: user, name: "Other List")
      create(:task, list: other_list, creator: user)

      get "/api/v1/tasks/all_tasks", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json).to have_key("tombstones")
      expect(json["tasks"]).to be_a(Array)
      expect(json["tombstones"]).to be_a(Array)
    end

    it 'should filter tasks by status' do
      completed_task = create(:task, list: list, creator: user, status: :done)

      get "/api/v1/tasks/all_tasks?status=completed", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")

      task_ids = json["tasks"].map { |t| t["id"] }
      expect(task_ids).to include(completed_task.id)
      expect(task_ids).not_to include(task.id)
    end

    it 'should filter tasks by list_id' do
      other_list = create(:list, user: user, name: "Other List")
      other_task = create(:task, list: other_list, creator: user)

      get "/api/v1/tasks/all_tasks?list_id=#{other_list.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")

      task_ids = json["tasks"].map { |t| t["id"] }
      expect(task_ids).to include(other_task.id)
      expect(task_ids).not_to include(task.id)
    end

    it 'should not get tasks without authentication' do
      get "/api/v1/lists/#{list.id}/tasks"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not get tasks from other user\'s list' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)

      get "/api/v1/lists/#{other_list.id}/tasks", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/tasks/:id' do
    it 'should show task' do
      get "/api/v1/tasks/#{task.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(task.id)
      expect(json["title"]).to eq(task.title)
    end

    it 'should not show task without authentication' do
      get "/api/v1/tasks/#{task.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not show task from other user' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)
      other_task = create(:task, list: other_list, creator: other_user)

      get "/api/v1/tasks/#{other_task.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/lists/:list_id/tasks' do
    it 'should create task' do
      task_params = {
        title: "New Task",
        note: "Task description",
        due_at: 1.hour.from_now.iso8601,
        strict_mode: true
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Task")
      expect(json["note"]).to eq("Task description")
    end

    it 'should not create task without authentication' do
      task_params = {
        title: "New Task",
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params

      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not create task in other user\'s list' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)

      task_params = {
        title: "New Task",
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/lists/#{other_list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'should validate required fields' do
      task_params = {
        note: "Task description"
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["details"]).to have_key("title")
    end
  end

  describe 'PATCH /api/v1/tasks/:id' do
    it 'should update task' do
      update_params = {
        title: "Updated Task",
        note: "Updated description"
      }

      patch "/api/v1/tasks/#{task.id}", params: update_params, headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Updated Task")
      expect(json["note"]).to eq("Updated description")
    end

    it 'should not update task without authentication' do
      update_params = {
        title: "Updated Task"
      }

      patch "/api/v1/tasks/#{task.id}", params: update_params

      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not update task from other user' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)
      other_task = create(:task, list: other_list, creator: other_user)

      update_params = {
        title: "Updated Task"
      }

      patch "/api/v1/tasks/#{other_task.id}", params: update_params, headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /api/v1/tasks/:id' do
    it 'should delete task' do
      delete "/api/v1/tasks/#{task.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(Task.find_by(id: task.id)).to be_nil
    end

    it 'should not delete task without authentication' do
      delete "/api/v1/tasks/#{task.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not delete task from other user' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)
      other_task = create(:task, list: other_list, creator: other_user)

      delete "/api/v1/tasks/#{other_task.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v1/tasks/:id/complete' do
    it 'should complete task' do
      patch "/api/v1/tasks/#{task.id}/complete", headers: auth_headers

      expect(response).to have_http_status(:success)
      task.reload
      expect(task.status).to eq("done")
      expect(task.completed_at).not_to be_nil
    end

    it 'should not complete task without authentication' do
      patch "/api/v1/tasks/#{task.id}/complete"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not complete task from other user' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)
      other_task = create(:task, list: other_list, creator: other_user)

      patch "/api/v1/tasks/#{other_task.id}/complete", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v1/tasks/:id/uncomplete' do
    it 'should uncomplete task' do
      task.update!(status: :done, completed_at: Time.current)

      patch "/api/v1/tasks/#{task.id}/uncomplete", headers: auth_headers

      expect(response).to have_http_status(:success)
      task.reload
      expect(task.status).to eq("pending")
      expect(task.completed_at).to be_nil
    end

    it 'should not uncomplete task without authentication' do
      patch "/api/v1/tasks/#{task.id}/uncomplete"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/tasks/:id/reassign' do
    it 'should reassign task' do
      other_user = create(:user)
      list.share_with!(other_user, { can_view: true, can_edit: true, can_add_items: true, can_delete_items: true })

      reassign_params = {
        assigned_to: other_user.id
      }

      patch "/api/v1/tasks/#{task.id}/reassign", params: reassign_params, headers: auth_headers

      expect(response).to have_http_status(:success)
      task.reload
      expect(task.assigned_to).to eq(other_user)
    end

    it 'should not reassign task without authentication' do
      reassign_params = {
        assigned_to: user.id
      }

      patch "/api/v1/tasks/#{task.id}/reassign", params: reassign_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/tasks/:id/submit_explanation' do
    it 'should submit explanation for missed task' do
      task.update!(requires_explanation_if_missed: true, due_at: 1.hour.ago, status: :pending)

      explanation_params = {
        missed_reason: "I was sick and couldn't complete the task"
      }

      post "/api/v1/tasks/#{task.id}/submit_explanation", params: explanation_params, headers: auth_headers

      expect(response).to have_http_status(:success)
      task.reload
      expect(task.missed_reason).to eq("I was sick and couldn't complete the task")
      expect(task.missed_reason_submitted_at).not_to be_nil
    end

    it 'should not submit explanation without authentication' do
      explanation_params = {
        missed_reason: "I was sick"
      }

      post "/api/v1/tasks/#{task.id}/submit_explanation", params: explanation_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/tasks/:id/toggle_visibility' do
    it 'should toggle task visibility' do
      visibility_params = {
        visibility: "hidden_from_coaches"
      }

      patch "/api/v1/tasks/#{task.id}/toggle_visibility", params: visibility_params, headers: auth_headers

      expect(response).to have_http_status(:success)
      task.reload
      expect(task.visibility).to eq("hidden_from_coaches")
    end

    it 'should not toggle visibility without authentication' do
      visibility_params = {
        visibility: "hidden_from_coaches"
      }

      patch "/api/v1/tasks/#{task.id}/toggle_visibility", params: visibility_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/tasks/:id/add_subtask' do
    it 'should add subtask' do
      subtask_params = {
        title: "Subtask",
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/tasks/#{task.id}/add_subtask", params: subtask_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Subtask")
      expect(json["parent_task_id"]).to eq(task.id)
    end

    it 'should not add subtask without authentication' do
      subtask_params = {
        title: "Subtask",
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/tasks/#{task.id}/add_subtask", params: subtask_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/tasks/:id/update_subtask' do
    it 'should update subtask' do
      subtask = create(:task, list: list, creator: user, parent_task: task, due_at: 30.minutes.from_now)

      update_params = {
        title: "Updated Subtask"
      }

      patch "/api/v1/tasks/#{subtask.id}/update_subtask", params: update_params, headers: auth_headers

      expect(response).to have_http_status(:success)
      subtask.reload
      expect(subtask.title).to eq("Updated Subtask")
    end

    it 'should not update subtask without authentication' do
      subtask = create(:task, list: list, creator: user, parent_task: task, due_at: 30.minutes.from_now)

      update_params = {
        title: "Updated Subtask"
      }

      patch "/api/v1/tasks/#{subtask.id}/update_subtask", params: update_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/tasks/:id/delete_subtask' do
    it 'should delete subtask' do
      subtask = create(:task, list: list, creator: user, parent_task: task, due_at: 30.minutes.from_now)

      delete "/api/v1/tasks/#{subtask.id}/delete_subtask", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(Task.find_by(id: subtask.id)).to be_nil
    end

    it 'should not delete subtask without authentication' do
      subtask = create(:task, list: list, creator: user, parent_task: task, due_at: 30.minutes.from_now)

      delete "/api/v1/tasks/#{subtask.id}/delete_subtask"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/tasks/overdue' do
    it 'should get overdue tasks' do
      overdue_task = create(:task, list: list, creator: user, due_at: 1.hour.ago, status: :pending)

      get "/api/v1/tasks/overdue", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json["tasks"]).to be_a(Array)
    end

    it 'should not get overdue tasks without authentication' do
      get "/api/v1/tasks/overdue"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/tasks/awaiting_explanation' do
    it 'should get tasks awaiting explanation' do
      task.update!(requires_explanation_if_missed: true, due_at: 1.hour.ago, status: :pending)

      get "/api/v1/tasks/awaiting_explanation", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json["tasks"]).to be_a(Array)
    end

    it 'should not get tasks awaiting explanation without authentication' do
      get "/api/v1/tasks/awaiting_explanation"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'error handling' do
    it 'should handle malformed JSON' do
      post "/api/v1/lists/#{list.id}/tasks",
           params: "invalid json",
           headers: auth_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it 'should handle empty request body' do
      post "/api/v1/lists/#{list.id}/tasks",
           params: "",
           headers: auth_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it 'should handle very long task titles' do
      long_title = "a" * 1000
      task_params = {
        title: long_title,
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'should handle special characters in task title' do
      special_title = "Task with special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?"
      task_params = {
        title: special_title,
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:created)
    end

    it 'should handle unicode characters in task title' do
      unicode_title = "Task with unicode: 你好世界 🌍"
      task_params = {
        title: unicode_title,
        due_at: 1.hour.from_now.iso8601
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:created)
    end
  end
end
