# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lists API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /api/v1/lists" do
    let!(:owned_list) { create(:list, user: user, name: "My List") }
    let!(:shared_list) { create(:list, user: other_user, name: "Shared List") }
    let!(:other_list) { create(:list, user: other_user, name: "Private List") }

    before do
      shared_list.memberships.create!(user: user, role: "viewer")
    end

    context "when authenticated" do
      it "returns owned and shared lists" do
        auth_get "/api/v1/lists", user: user

        expect(response).to have_http_status(:ok)
        list_ids = json_response["lists"].map { |l| l["id"] }
        expect(list_ids).to include(owned_list.id, shared_list.id)
        expect(list_ids).not_to include(other_list.id)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/lists"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/lists/:id" do
    let(:list) { create(:list, user: user) }

    context "as owner" do
      it "returns the list" do
        auth_get "/api/v1/lists/#{list.id}", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["id"]).to eq(list.id)
        expect(json_response["name"]).to eq(list.name)
      end
    end

    context "as member" do
      before { list.memberships.create!(user: other_user, role: "viewer") }

      it "returns the list" do
        auth_get "/api/v1/lists/#{list.id}", user: other_user

        expect(response).to have_http_status(:ok)
        expect(json_response["id"]).to eq(list.id)
      end
    end

    context "as stranger" do
      it "returns forbidden" do
        auth_get "/api/v1/lists/#{list.id}", user: other_user

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with tasks" do
      let!(:task) { create(:task, list: list, creator: user) }

      it "includes tasks in response" do
        auth_get "/api/v1/lists/#{list.id}", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["tasks"]).to be_present
        expect(json_response["tasks"].first["id"]).to eq(task.id)
      end
    end
  end

  describe "POST /api/v1/lists" do
    let(:valid_params) { { list: { name: "New List", description: "A new list", color: "blue" } } }

    context "with valid params" do
      it "creates a list" do
        expect {
          auth_post "/api/v1/lists", user: user, params: valid_params
        }.to change(List, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response["name"]).to eq("New List")
      end
    end

    context "with invalid params" do
      it "returns error for missing name" do
        auth_post "/api/v1/lists", user: user, params: { list: { description: "No name" } }

        expect(response.status).to be_in([400, 422])
      end
    end
  end

  describe "PATCH /api/v1/lists/:id" do
    let(:list) { create(:list, user: user, name: "Original Name") }

    context "as owner" do
      it "updates the list" do
        auth_patch "/api/v1/lists/#{list.id}", user: user, params: { list: { name: "Updated Name" } }

        expect(response).to have_http_status(:ok)
        expect(list.reload.name).to eq("Updated Name")
      end
    end

    context "as editor" do
      before { list.memberships.create!(user: other_user, role: "editor") }

      it "updates the list" do
        auth_patch "/api/v1/lists/#{list.id}", user: other_user, params: { list: { name: "Editor Update" } }

        expect(response).to have_http_status(:ok)
        expect(list.reload.name).to eq("Editor Update")
      end
    end

    context "as viewer" do
      before { list.memberships.create!(user: other_user, role: "viewer") }

      it "returns forbidden" do
        auth_patch "/api/v1/lists/#{list.id}", user: other_user, params: { list: { name: "Viewer Update" } }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/lists/:id" do
    let!(:list) { create(:list, user: user) }

    context "as owner" do
      it "soft deletes the list" do
        auth_delete "/api/v1/lists/#{list.id}", user: user

        expect(response).to have_http_status(:no_content)
        expect(list.reload.deleted?).to be true
      end
    end

    context "as stranger" do
      it "returns forbidden" do
        auth_delete "/api/v1/lists/#{list.id}", user: other_user

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end