# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Security", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password:, password_confirmation: password) }
  let(:list) { create(:list, user:) }
  let!(:task) { create(:task, list:, creator: user) }

  def json
    JSON.parse(response.body) rescue {}
  end

  def auth_headers_for(u, password: "password123")
    post "/api/v1/auth/sign_in",
         params: { user: { email: u.email, password: password } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    auth = response.headers["Authorization"]
    raise "Missing Authorization header" if auth.blank?

    { "Authorization" => auth, "ACCEPT" => "application/json" }
  end

  describe "Authentication" do
    it "rejects access to protected endpoints without a token" do
      get "/api/v1/lists"
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/tasks"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects invalid Authorization headers" do
      invalid_headers = [
        { "Authorization" => "invalid_token" },
        { "Authorization" => "Bearer invalid_token" },
        { "Authorization" => "Bearer " }
      ]

      invalid_headers.each do |hdrs|
        get "/api/v1/lists", headers: hdrs
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "accepts valid JWT and returns data" do
      headers = auth_headers_for(user)

      get "/api/v1/lists", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Cross-user access isolation" do
    let(:other_user) { create(:user, password:, password_confirmation: password) }
    let(:other_list) { create(:list, user: other_user) }
    let(:other_task) { create(:task, list: other_list, creator: other_user) }

    it "prevents user B from reading user A's list" do
      b_headers = auth_headers_for(other_user)

      get "/api/v1/lists/#{list.id}", headers: b_headers
      expect([403, 404]).to include(response.status)
    end

    it "prevents user B from reading user A's tasks" do
      b_headers = auth_headers_for(other_user)

      get "/api/v1/lists/#{list.id}/tasks", headers: b_headers
      expect([403, 404]).to include(response.status)
    end

    it "allows the owner to read their own resources" do
      a_headers = auth_headers_for(user)

      get "/api/v1/lists/#{list.id}", headers: a_headers
      expect(response).to have_http_status(:ok)

      get "/api/v1/lists/#{list.id}/tasks", headers: a_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Input hardening" do
    it "handles malformed JSON with a 400" do
      headers = auth_headers_for(user)

      post "/api/v1/lists/#{list.id}/tasks",
           params: "not-json",
           headers: headers.merge("CONTENT_TYPE" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it "does not allow mass-assigning user_id on list creation" do
      headers = auth_headers_for(user)
      attacker = create(:user, password:, password_confirmation: password)

      post "/api/v1/lists",
           params: { name: "test", user_id: attacker.id },
           headers: headers

      expect([201, 400, 422]).to include(response.status)

      if response.status == 201
        created_id = json["id"]
        expect(created_id).to be_present
        created = List.find(created_id)
        expect(created.user_id).to eq(user.id) # must be current_user, not attacker
      end
    end
  end
end
