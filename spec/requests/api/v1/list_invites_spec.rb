# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ListInvites", type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/lists/:list_id/invites" do
    it "returns list of invites" do
      create_list(:list_invite, 3, list: list, inviter: user)

      get "/api/v1/lists/#{list.id}/invites", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["invites"].length).to eq(3)
    end

    it "returns 404 for non-owner (no info leakage)" do
      other_user = create(:user)

      get "/api/v1/lists/#{list.id}/invites", headers: auth_headers(other_user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/lists/:list_id/invites" do
    it "creates an invite with default role" do
      post "/api/v1/lists/#{list.id}/invites",
           params: { invite: {} }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response["invite"]["code"]).to be_present
      expect(json_response["invite"]["role"]).to eq("viewer")
      expect(json_response["invite"]["invite_url"]).to include("/invite/")
    end

    it "creates an invite with specified role" do
      post "/api/v1/lists/#{list.id}/invites",
           params: { invite: { role: "editor" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response["invite"]["role"]).to eq("editor")
    end

    it "creates an invite with expiration" do
      expires = 7.days.from_now.iso8601

      post "/api/v1/lists/#{list.id}/invites",
           params: { invite: { expires_at: expires } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response["invite"]["expires_at"]).to be_present
    end

    it "creates an invite with max uses" do
      post "/api/v1/lists/#{list.id}/invites",
           params: { invite: { max_uses: 5 } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response["invite"]["max_uses"]).to eq(5)
    end

    it "returns 400 when invite payload is not an object" do
      post "/api/v1/lists/#{list.id}/invites",
           params: { invite: "invalid" }.to_json,
           headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]["message"]).to eq("invite must be an object")
    end
  end

  describe "DELETE /api/v1/lists/:list_id/invites/:id" do
    let!(:invite) { create(:list_invite, list: list, inviter: user) }

    it "deletes the invite" do
      expect {
        delete "/api/v1/lists/#{list.id}/invites/#{invite.id}", headers: headers
      }.to change(ListInvite, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
