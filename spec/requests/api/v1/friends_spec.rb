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
      expect(names).to eq([ "Alice", "Zack" ])
    end

    it "requires authentication" do
      get "/api/v1/friends"

      expect(response).to have_http_status(:unauthorized)
    end

    describe "with exclude_list_id parameter" do
      let(:list) { create(:list, user: user) }
      let(:friend_on_list) { create(:user, name: "On List") }
      let(:friend_not_on_list) { create(:user, name: "Not On List") }

      before do
        Friendship.create_mutual!(user, friend_on_list)
        Friendship.create_mutual!(user, friend_not_on_list)
        create(:membership, list: list, user: friend_on_list, role: "editor")
      end

      it "excludes friends who are already members of the list" do
        get "/api/v1/friends", headers: headers, params: { exclude_list_id: list.id }

        expect(response).to have_http_status(:ok)
        names = json_response["friends"].map { |f| f["name"] }
        expect(names).to include("Not On List")
        expect(names).not_to include("On List")
      end

      it "excludes the list owner from results when user is member" do
        # Create another user who owns a list and is friends with user
        other_owner = create(:user, name: "Other Owner")
        other_list = create(:list, user: other_owner)
        Friendship.create_mutual!(user, other_owner)
        # User must be a member of the list for filtering to apply
        create(:membership, list: other_list, user: user, role: "editor")

        get "/api/v1/friends", headers: headers, params: { exclude_list_id: other_list.id }

        expect(response).to have_http_status(:ok)
        names = json_response["friends"].map { |f| f["name"] }
        expect(names).not_to include("Other Owner")
      end

      it "returns all friends when exclude_list_id is not provided" do
        get "/api/v1/friends", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response["friends"].length).to eq(2)
      end

      it "returns all friends when list does not exist" do
        get "/api/v1/friends", headers: headers, params: { exclude_list_id: 999999 }

        expect(response).to have_http_status(:ok)
        expect(json_response["friends"].length).to eq(2)
      end

      it "returns all friends when user has no access to the list" do
        other_user = create(:user)
        private_list = create(:list, user: other_user)

        get "/api/v1/friends", headers: headers, params: { exclude_list_id: private_list.id }

        expect(response).to have_http_status(:ok)
        # Should not filter because user can't access the list
        expect(json_response["friends"].length).to eq(2)
      end

      it "updates pagination total_count correctly" do
        get "/api/v1/friends", headers: headers, params: { exclude_list_id: list.id }

        expect(json_response["pagination"]["total_count"]).to eq(1)
      end
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
