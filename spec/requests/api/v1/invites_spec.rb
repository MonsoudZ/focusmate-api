# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Invites", type: :request do
  let(:owner) { create(:user) }
  let(:list) { create(:list, user: owner) }
  let(:invite) { create(:list_invite, list: list, inviter: owner, role: "editor") }

  describe "GET /api/v1/invites/:code" do
    it "returns invite preview without authentication" do
      get "/api/v1/invites/#{invite.code}"

      expect(response).to have_http_status(:ok)
      expect(json_response["invite"]["code"]).to eq(invite.code)
      expect(json_response["invite"]["role"]).to eq("editor")
      expect(json_response["invite"]["list"]["name"]).to eq(list.name)
      expect(json_response["invite"]["inviter"]["name"]).to eq(owner.name)
    end

    it "is case insensitive" do
      get "/api/v1/invites/#{invite.code.downcase}"

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for invalid code" do
      get "/api/v1/invites/INVALID"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/invites/:code/accept" do
    let(:user) { create(:user) }
    let(:headers) { auth_headers(user) }

    it "adds user to the list" do
      expect {
        post "/api/v1/invites/#{invite.code}/accept", headers: headers
      }.to change(Membership, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response["list"]["id"]).to eq(list.id)
    end

    it "assigns the correct role" do
      post "/api/v1/invites/#{invite.code}/accept", headers: headers

      membership = Membership.last
      expect(membership.role).to eq("editor")
    end

    it "increments uses_count" do
      expect {
        post "/api/v1/invites/#{invite.code}/accept", headers: headers
      }.to change { invite.reload.uses_count }.by(1)
    end

    it "creates mutual friendship with inviter" do
      expect {
        post "/api/v1/invites/#{invite.code}/accept", headers: headers
      }.to change(Friendship, :count).by(2)

      expect(Friendship.friends?(owner, user)).to be true
    end

    it "does not duplicate friendship if already friends" do
      Friendship.create_mutual!(owner, user)

      expect {
        post "/api/v1/invites/#{invite.code}/accept", headers: headers
      }.not_to change(Friendship, :count)
    end

    it "returns 410 for expired invite" do
      expired_invite = create(:list_invite, :expired, list: list, inviter: owner)

      post "/api/v1/invites/#{expired_invite.code}/accept", headers: headers

      expect(response).to have_http_status(:gone)
      expect(json_response["error"]["message"]).to eq("This invite has expired")
    end

    it "returns 410 for exhausted invite" do
      exhausted_invite = create(:list_invite, :exhausted, list: list, inviter: owner)

      post "/api/v1/invites/#{exhausted_invite.code}/accept", headers: headers

      expect(response).to have_http_status(:gone)
      expect(json_response["error"]["message"]).to eq("This invite has reached its usage limit")
    end

    it "returns 422 if user is owner" do
      post "/api/v1/invites/#{invite.code}/accept", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]["message"]).to eq("You are the owner of this list")
    end

    it "returns 409 if already a member" do
      create(:membership, list: list, user: user)

      post "/api/v1/invites/#{invite.code}/accept", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(json_response["error"]["message"]).to eq("You are already a member of this list")
    end

    it "requires authentication" do
      post "/api/v1/invites/#{invite.code}/accept"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
