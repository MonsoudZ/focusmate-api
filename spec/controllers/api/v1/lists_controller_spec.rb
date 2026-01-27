# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ListsController, type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:auth_headers) do
    post "/api/v1/auth/sign_in",
         params: { user: { email: user.email, password: "password123" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    raise "Missing Authorization header in auth_headers" if token.blank?

    { "Authorization" => token, "ACCEPT" => "application/json" }
  end

  describe 'GET /api/v1/lists' do
    it 'returns lists owned by user' do
      list # force creation
      list2 = create(:list, user: user, name: "Second List")

      get "/api/v1/lists", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("lists")
      expect(json).to have_key("tombstones")
      expect(json["lists"]).to be_a(Array)

      list_ids = json["lists"].map { |l| l["id"] }
      expect(list_ids).to include(list.id, list2.id)
    end

    it 'returns lists user is a member of' do
      list # force creation
      other_user = create(:user)
      shared_list = create(:list, user: other_user, name: "Shared List")
      create(:membership, list: shared_list, user: user, role: "viewer")

      get "/api/v1/lists", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      list_ids = json["lists"].map { |l| l["id"] }
      expect(list_ids).to include(list.id, shared_list.id)
    end

    it 'requires authentication' do
      get "/api/v1/lists"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'handles empty lists' do
      List.where(user: user).destroy_all

      get "/api/v1/lists", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["lists"]).to be_empty
    end
  end

  describe 'GET /api/v1/lists/:id' do
    it 'shows list owned by user' do
      get "/api/v1/lists/#{list.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(list.id)
      expect(json["name"]).to eq(list.name)
    end

    it 'requires authentication' do
      get "/api/v1/lists/#{list.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids access to other users list' do
      other_user = create(:user)
      other_list = create(:list, user: other_user)

      get "/api/v1/lists/#{other_list.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows access to list user is member of' do
      other_user = create(:user)
      shared_list = create(:list, user: other_user)
      create(:membership, list: shared_list, user: user, role: "viewer")

      get "/api/v1/lists/#{shared_list.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(shared_list.id)
    end
  end

  describe 'POST /api/v1/lists' do
    it 'creates a list' do
      list_params = { name: "New List", description: "A new list", visibility: "private" }

      post "/api/v1/lists", params: list_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New List")
      expect(json["description"]).to eq("A new list")
    end

    it 'requires authentication' do
      post "/api/v1/lists", params: { name: "New List" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'validates required fields' do
      post "/api/v1/lists", params: { description: "No name" }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("validation_error")
      expect(json["error"]["details"]).to have_key("name")
    end

    it 'sets default visibility to private' do
      post "/api/v1/lists", params: { name: "New List" }, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json).to have_key("name")
    end
  end

  describe 'PATCH /api/v1/lists/:id' do
    it 'updates list' do
      patch "/api/v1/lists/#{list.id}", params: { name: "Updated" }, headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Updated")
    end

    it 'requires authentication' do
      patch "/api/v1/lists/#{list.id}", params: { name: "Updated" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids updating other users list' do
      other_list = create(:list, user: create(:user))

      patch "/api/v1/lists/#{other_list.id}", params: { name: "Updated" }, headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /api/v1/lists/:id' do
    it 'deletes list' do
      delete "/api/v1/lists/#{list.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(List.find_by(id: list.id)).to be_nil
    end

    it 'requires authentication' do
      delete "/api/v1/lists/#{list.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids deleting other users list' do
      other_list = create(:list, user: create(:user))

      delete "/api/v1/lists/#{other_list.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids deleting list user is only member of' do
      other_user = create(:user)
      shared_list = create(:list, user: other_user)
      create(:membership, list: shared_list, user: user, role: "editor")

      delete "/api/v1/lists/#{shared_list.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/lists/:id/tasks' do
    it 'returns tasks for list' do
      create(:task, list: list, creator: user)
      create(:task, list: list, creator: user)

      get "/api/v1/lists/#{list.id}/tasks", headers: auth_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json["tasks"]).to be_a(Array)
      expect(json["tasks"].length).to eq(2)
    end

    it 'requires authentication' do
      get "/api/v1/lists/#{list.id}/tasks"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids access to other users list tasks' do
      other_list = create(:list, user: create(:user))

      get "/api/v1/lists/#{other_list.id}/tasks", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'error handling' do
    it 'handles malformed JSON' do
      post "/api/v1/lists",
           params: "invalid json",
           headers: auth_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it 'handles very long list names' do
      post "/api/v1/lists", params: { name: "a" * 1000 }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'handles special characters in list name' do
      post "/api/v1/lists", params: { name: "List !@#$%^&*()" }, headers: auth_headers

      expect(response).to have_http_status(:created)
    end

    it 'handles unicode characters in list name' do
      post "/api/v1/lists", params: { name: "List 你好 🌍" }, headers: auth_headers

      expect(response).to have_http_status(:created)
    end
  end
end
