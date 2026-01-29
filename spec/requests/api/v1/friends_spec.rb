# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Friends", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/friends" do
    it "returns empty array when no friends" do
      get "/api/v1/friends", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["friends"]).to eq([])
    end

    it "returns list of friends" do
      friend1 = create(:user, name: "Alice")
      friend2 = create(:user, name: "Bob")
      Friendship.create_mutual!(user, friend1)
      Friendship.create_mutual!(user, friend2)

      get "/api/v1/friends", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["friends"].length).to eq(2)
      expect(json_response["friends"].map { |f| f["name"] }).to contain_exactly("Alice", "Bob")
    end

    it "returns friends ordered by name" do
      friend_z = create(:user, name: "Zack")
      friend_a = create(:user, name: "Alice")
      Friendship.create_mutual!(user, friend_z)
      Friendship.create_mutual!(user, friend_a)

      get "/api/v1/friends", headers: headers

      names = json_response["friends"].map { |f| f["name"] }
      expect(names).to eq(["Alice", "Zack"])
    end

    it "requires authentication" do
      get "/api/v1/friends"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/friends/:id" do
    let(:friend) { create(:user) }

    before do
      Friendship.create_mutual!(user, friend)
    end

    it "removes the friendship" do
      expect {
        delete "/api/v1/friends/#{friend.id}", headers: headers
      }.to change(Friendship, :count).by(-2)

      expect(response).to have_http_status(:no_content)
    end

    it "removes friendship in both directions" do
      delete "/api/v1/friends/#{friend.id}", headers: headers

      expect(user.reload.friends).not_to include(friend)
      expect(friend.reload.friends).not_to include(user)
    end

    it "returns 404 if not friends" do
      stranger = create(:user)

      delete "/api/v1/friends/#{stranger.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json_response["error"]["message"]).to eq("Not friends with this user")
    end

    it "requires authentication" do
      delete "/api/v1/friends/#{friend.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
