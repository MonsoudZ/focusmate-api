# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tags API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /api/v1/tags" do
    let!(:tag1) { create(:tag, user: user, name: "Work") }
    let!(:tag2) { create(:tag, user: user, name: "Personal") }
    let!(:other_tag) { create(:tag, user: other_user, name: "Other") }

    context "when authenticated" do
      it "returns user's tags" do
        auth_get "/api/v1/tags", user: user

        expect(response).to have_http_status(:ok)
        tag_ids = json_response["tags"].map { |t| t["id"] }
        expect(tag_ids).to include(tag1.id, tag2.id)
        expect(tag_ids).not_to include(other_tag.id)
      end

      it "returns tags in alphabetical order" do
        auth_get "/api/v1/tags", user: user

        names = json_response["tags"].map { |t| t["name"] }
        expect(names).to eq(names.sort)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/tags"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/tags/:id" do
    let(:tag) { create(:tag, user: user) }

    context "as owner" do
      it "returns the tag" do
        auth_get "/api/v1/tags/#{tag.id}", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["id"]).to eq(tag.id)
      end
    end

    context "as other user" do
      it "returns not found" do
        auth_get "/api/v1/tags/#{tag.id}", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/tags" do
    let(:valid_params) { { tag: { name: "New Tag", color: "blue" } } }

    context "with valid params" do
      it "creates a tag" do
        expect {
          auth_post "/api/v1/tags", user: user, params: valid_params
        }.to change(Tag, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response["name"]).to eq("New Tag")
      end

      it "sets the current user as owner" do
        auth_post "/api/v1/tags", user: user, params: valid_params

        tag = Tag.last
        expect(tag.user).to eq(user)
      end
    end

    context "with invalid params" do
      it "returns error for missing name" do
        auth_post "/api/v1/tags", user: user, params: { tag: { color: "blue" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error for duplicate name" do
        create(:tag, user: user, name: "Existing")

        auth_post "/api/v1/tags", user: user, params: { tag: { name: "Existing" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /api/v1/tags/:id" do
    let(:tag) { create(:tag, user: user, name: "Original") }

    context "as owner" do
      it "updates the tag" do
        auth_patch "/api/v1/tags/#{tag.id}", user: user, params: { tag: { name: "Updated" } }

        expect(response).to have_http_status(:ok)
        expect(tag.reload.name).to eq("Updated")
      end
    end

    context "as other user" do
      it "returns not found" do
        auth_patch "/api/v1/tags/#{tag.id}", user: other_user, params: { tag: { name: "Hacked" } }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/tags/:id" do
    let!(:tag) { create(:tag, user: user) }

    context "as owner" do
      it "deletes the tag" do
        expect {
          auth_delete "/api/v1/tags/#{tag.id}", user: user
        }.to change(Tag, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "as other user" do
      it "returns not found" do
        auth_delete "/api/v1/tags/#{tag.id}", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end