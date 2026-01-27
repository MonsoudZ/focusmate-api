# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TasksController, type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  let(:auth_headers) do
    post "/api/v1/auth/sign_in",
         params: { user: { email: user.email, password: "password123" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    raise "Missing Authorization header" if token.blank?

    { "Authorization" => token, "ACCEPT" => "application/json" }
  end

  describe 'GET /api/v1/lists/:list_id/tasks' do
    it 'returns tasks for list' do
      task # force creation

      get "/api/v1/lists/#{list.id}/tasks", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json["tasks"]).to be_a(Array)
    end

    it 'requires authentication' do
      get "/api/v1/lists/#{list.id}/tasks"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids access to other users list' do
      other_list = create(:list, user: create(:user))

      get "/api/v1/lists/#{other_list.id}/tasks", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/lists/:list_id/tasks/:id' do
    it 'returns the task' do
      get "/api/v1/lists/#{list.id}/tasks/#{task.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(task.id)
    end

    it 'requires authentication' do
      get "/api/v1/lists/#{list.id}/tasks/#{task.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/lists/:list_id/tasks' do
    it 'creates a task' do
      task_params = {
        title: "New Task",
        due_at: 1.day.from_now.iso8601,
        strict_mode: false
      }

      post "/api/v1/lists/#{list.id}/tasks", params: task_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Task")
    end

    it 'requires authentication' do
      post "/api/v1/lists/#{list.id}/tasks", params: { title: "Test" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'validates required fields' do
      post "/api/v1/lists/#{list.id}/tasks", params: { note: "No title" }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/lists/:list_id/tasks/:id' do
    it 'updates the task' do
      patch "/api/v1/lists/#{list.id}/tasks/#{task.id}",
            params: { title: "Updated Task" },
            headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Updated Task")
    end

    it 'requires authentication' do
      patch "/api/v1/lists/#{list.id}/tasks/#{task.id}", params: { title: "Updated" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/lists/:list_id/tasks/:id' do
    it 'deletes the task' do
      delete "/api/v1/lists/#{list.id}/tasks/#{task.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
    end

    it 'requires authentication' do
      delete "/api/v1/lists/#{list.id}/tasks/#{task.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/lists/:list_id/tasks/:id/complete' do
    it 'completes the task' do
      patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/complete", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(task.reload.status).to eq("done")
    end

    it 'requires authentication' do
      patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/complete"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
