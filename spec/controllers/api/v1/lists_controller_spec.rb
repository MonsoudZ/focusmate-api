# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ListsController, type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:list, owner: user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.credentials.secret_key_base)}" } }

  describe 'GET /api/v1/lists' do
    it 'should get all lists owned by user' do
      # Create additional lists for the user
      list2 = create(:list, owner: user, name: "Second List")
      list3 = create(:list, owner: user, name: "Third List")
      
      get "/api/v1/lists", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("lists")
      expect(json).to have_key("tombstones")
      expect(json["lists"]).to be_a(Array)
      expect(json["tombstones"]).to be_a(Array)
      
      list_ids = json["lists"].map { |l| l["id"] }
      expect(list_ids).to include(list.id)
      expect(list_ids).to include(list2.id)
      expect(list_ids).to include(list3.id)
    end

    it 'should get lists shared with user' do
      other_user = create(:user, email: "other@example.com")
      shared_list = create(:list, owner: other_user, name: "Shared List")
      
      # Share list with current user
      create(:list_share, list: shared_list, user: user, status: "accepted", invited_by: "owner")
      
      get "/api/v1/lists", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("lists")
      
      list_ids = json["lists"].map { |l| l["id"] }
      expect(list_ids).to include(list.id) # Owned list
      expect(list_ids).to include(shared_list.id) # Shared list
    end

    it 'should not get lists without authentication' do
      get "/api/v1/lists"
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should handle empty lists' do
      # Delete all lists for user
      List.where(owner: user).destroy_all
      
      get "/api/v1/lists", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["lists"]).to be_empty
    end
  end

  describe 'GET /api/v1/lists/:id' do
    it 'should show list' do
      get "/api/v1/lists/#{list.id}", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(list.id)
      expect(json["name"]).to eq(list.name)
    end

    it 'should not show list without authentication' do
      get "/api/v1/lists/#{list.id}"
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not show list from other user' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      
      get "/api/v1/lists/#{other_list.id}", headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end

    it 'should show shared list' do
      other_user = create(:user)
      shared_list = create(:list, owner: other_user)
      create(:list_share, list: shared_list, user: user, status: "accepted", invited_by: "owner")
      
      get "/api/v1/lists/#{shared_list.id}", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(shared_list.id)
    end
  end

  describe 'POST /api/v1/lists' do
    it 'should create list' do
      list_params = {
        name: "New List",
        description: "A new list",
        visibility: "private"
      }
      
      post "/api/v1/lists", params: list_params, headers: auth_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New List")
      expect(json["description"]).to eq("A new list")
      expect(json["visibility"]).to eq("private")
    end

    it 'should not create list without authentication' do
      list_params = {
        name: "New List",
        description: "A new list"
      }
      
      post "/api/v1/lists", params: list_params
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should validate required fields' do
      list_params = {
        description: "A list without name"
      }
      
      post "/api/v1/lists", params: list_params, headers: auth_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to have_key("name")
    end

    it 'should set default visibility' do
      list_params = {
        name: "New List"
      }
      
      post "/api/v1/lists", params: list_params, headers: auth_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["visibility"]).to eq("private")
    end
  end

  describe 'PATCH /api/v1/lists/:id' do
    it 'should update list' do
      update_params = {
        name: "Updated List",
        description: "Updated description"
      }
      
      patch "/api/v1/lists/#{list.id}", params: update_params, headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Updated List")
      expect(json["description"]).to eq("Updated description")
    end

    it 'should not update list without authentication' do
      update_params = {
        name: "Updated List"
      }
      
      patch "/api/v1/lists/#{list.id}", params: update_params
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not update list from other user' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      
      update_params = {
        name: "Updated List"
      }
      
      patch "/api/v1/lists/#{other_list.id}", params: update_params, headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end

    it 'should update shared list if user has edit permission' do
      other_user = create(:user)
      shared_list = create(:list, owner: other_user)
      create(:list_share, list: shared_list, user: user, status: "accepted", invited_by: "owner", can_edit: true)
      
      update_params = {
        name: "Updated Shared List"
      }
      
      patch "/api/v1/lists/#{shared_list.id}", params: update_params, headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Updated Shared List")
    end
  end

  describe 'DELETE /api/v1/lists/:id' do
    it 'should delete list' do
      delete "/api/v1/lists/#{list.id}", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      expect(List.find_by(id: list.id)).to be_nil
    end

    it 'should not delete list without authentication' do
      delete "/api/v1/lists/#{list.id}"
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not delete list from other user' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      
      delete "/api/v1/lists/#{other_list.id}", headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end

    it 'should not delete shared list' do
      other_user = create(:user)
      shared_list = create(:list, owner: other_user)
      create(:list_share, list: shared_list, user: user, status: "accepted", invited_by: "owner")
      
      delete "/api/v1/lists/#{shared_list.id}", headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/lists/:id/share' do
    it 'should share list with user' do
      other_user = create(:user, email: "shared@example.com")
      
      share_params = {
        email: other_user.email,
        can_view: true,
        can_edit: true,
        can_add_items: true,
        can_delete_items: false
      }
      
      post "/api/v1/lists/#{list.id}/share", params: share_params, headers: auth_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["user_id"]).to eq(other_user.id)
      expect(json["can_view"]).to be true
      expect(json["can_edit"]).to be true
      expect(json["can_add_items"]).to be true
      expect(json["can_delete_items"]).to be false
    end

    it 'should not share list without authentication' do
      share_params = {
        email: "shared@example.com",
        can_view: true
      }
      
      post "/api/v1/lists/#{list.id}/share", params: share_params
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not share list from other user' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      
      share_params = {
        email: "shared@example.com",
        can_view: true
      }
      
      post "/api/v1/lists/#{other_list.id}/share", params: share_params, headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end

    it 'should validate required fields' do
      share_params = {
        can_view: true
      }
      
      post "/api/v1/lists/#{list.id}/share", params: share_params, headers: auth_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to have_key("email")
    end
  end

  describe 'PATCH /api/v1/lists/:id/unshare' do
    it 'should unshare list with user' do
      other_user = create(:user, email: "shared@example.com")
      create(:list_share, list: list, user: other_user, status: "accepted", invited_by: "owner")
      
      unshare_params = {
        user_id: other_user.id
      }
      
      patch "/api/v1/lists/#{list.id}/unshare", params: unshare_params, headers: auth_headers
      
      expect(response).to have_http_status(:success)
      expect(ListShare.find_by(list: list, user: other_user)).to be_nil
    end

    it 'should not unshare list without authentication' do
      other_user = create(:user)
      
      unshare_params = {
        user_id: other_user.id
      }
      
      patch "/api/v1/lists/#{list.id}/unshare", params: unshare_params
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not unshare list from other user' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      create(:list_share, list: other_list, user: user, status: "accepted", invited_by: "owner")
      
      unshare_params = {
        user_id: user.id
      }
      
      patch "/api/v1/lists/#{other_list.id}/unshare", params: unshare_params, headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/lists/:id/members' do
    it 'should get list members' do
      other_user = create(:user, email: "member@example.com")
      create(:list_share, list: list, user: other_user, status: "accepted", invited_by: "owner")
      
      get "/api/v1/lists/#{list.id}/members", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("members")
      expect(json["members"]).to be_a(Array)
    end

    it 'should not get members without authentication' do
      get "/api/v1/lists/#{list.id}/members"
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not get members from other user\'s list' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      
      get "/api/v1/lists/#{other_list.id}/members", headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/lists/:id/tasks' do
    it 'should get tasks for list' do
      create(:task, list: list, creator: user)
      create(:task, list: list, creator: user)
      
      get "/api/v1/lists/#{list.id}/tasks", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("tasks")
      expect(json["tasks"]).to be_a(Array)
      expect(json["tasks"].length).to eq(2)
    end

    it 'should not get tasks without authentication' do
      get "/api/v1/lists/#{list.id}/tasks"
      
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should not get tasks from other user\'s list' do
      other_user = create(:user)
      other_list = create(:list, owner: other_user)
      
      get "/api/v1/lists/#{other_list.id}/tasks", headers: auth_headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'error handling' do
    it 'should handle malformed JSON' do
      post "/api/v1/lists", 
           params: "invalid json", 
           headers: auth_headers.merge("Content-Type" => "application/json")
      
      expect(response).to have_http_status(:bad_request)
    end

    it 'should handle empty request body' do
      post "/api/v1/lists", 
           params: "", 
           headers: auth_headers.merge("Content-Type" => "application/json")
      
      expect(response).to have_http_status(:bad_request)
    end

    it 'should handle very long list names' do
      long_name = "a" * 1000
      list_params = {
        name: long_name
      }
      
      post "/api/v1/lists", params: list_params, headers: auth_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'should handle special characters in list name' do
      special_name = "List with special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?"
      list_params = {
        name: special_name
      }
      
      post "/api/v1/lists", params: list_params, headers: auth_headers
      
      expect(response).to have_http_status(:created)
    end

    it 'should handle unicode characters in list name' do
      unicode_name = "List with unicode: 你好世界 🌍"
      list_params = {
        name: unicode_name
      }
      
      post "/api/v1/lists", params: list_params, headers: auth_headers
      
      expect(response).to have_http_status(:created)
    end
  end
end
