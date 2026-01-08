# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tasks Authorization", type: :request do
  let(:owner) { create(:user) }
  let(:editor) { create(:user) }
  let(:viewer) { create(:user) }
  let(:stranger) { create(:user) }
  let(:list) { create(:list, user: owner) }
  let!(:task) { create(:task, list: list, creator: owner) }

  before do
    list.memberships.create!(user: editor, role: "editor")
    list.memberships.create!(user: viewer, role: "viewer")
  end

  # Helper to get auth headers
  def auth_headers_for(user)
    post "/api/v1/auth/sign_in",
         params: { user: { email: user.email, password: "password123" } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    { "Authorization" => token, "Accept" => "application/json", "Content-Type" => "application/json" }
  end

  describe "POST /api/v1/lists/:list_id/tasks/reorder" do
    let(:reorder_params) { { tasks: [{ id: task.id, position: 1 }] } }

    context "as list owner" do
      it "allows reordering" do
        post "/api/v1/lists/#{list.id}/tasks/reorder",
             params: reorder_params.to_json,
             headers: auth_headers_for(owner)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as editor member" do
      it "allows reordering" do
        post "/api/v1/lists/#{list.id}/tasks/reorder",
             params: reorder_params.to_json,
             headers: auth_headers_for(editor)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as viewer member" do
      it "forbids reordering" do
        post "/api/v1/lists/#{list.id}/tasks/reorder",
             params: reorder_params.to_json,
             headers: auth_headers_for(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as stranger" do
      it "forbids reordering" do
        post "/api/v1/lists/#{list.id}/tasks/reorder",
             params: reorder_params.to_json,
             headers: auth_headers_for(stranger)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/lists/#{list.id}/tasks/reorder",
             params: reorder_params.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/tasks/search" do
    let!(:stranger_list) { create(:list, user: stranger) }
    let!(:stranger_task) { create(:task, list: stranger_list, creator: stranger, title: "Secret Project") }
    let!(:owner_task) { create(:task, list: list, creator: owner, title: "My Project") }

    it "only returns tasks from accessible lists" do
      get "/api/v1/tasks/search",
          params: { q: "Project" },
          headers: auth_headers_for(owner)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      task_ids = json["tasks"].map { |t| t["id"] }

      expect(task_ids).to include(owner_task.id)
      expect(task_ids).not_to include(stranger_task.id)
    end

    it "returns tasks from shared lists" do
      get "/api/v1/tasks/search",
          params: { q: "Project" },
          headers: auth_headers_for(viewer)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      task_ids = json["tasks"].map { |t| t["id"] }

      # Viewer can see tasks in lists they're a member of
      expect(task_ids).to include(owner_task.id)
      expect(task_ids).not_to include(stranger_task.id)
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:id/assign" do
    context "assigning to a list member" do
      it "succeeds" do
        patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/assign",
              params: { assigned_to: editor.id }.to_json,
              headers: auth_headers_for(owner)

        expect(response).to have_http_status(:ok)
        expect(task.reload.assigned_to_id).to eq(editor.id)
      end
    end

    context "assigning to a non-member" do
      it "fails with unprocessable entity" do
        patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/assign",
              params: { assigned_to: stranger.id }.to_json,
              headers: auth_headers_for(owner)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["message"]).to include("cannot be assigned")
      end
    end
  end
end