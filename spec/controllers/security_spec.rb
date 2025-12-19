# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Security", type: :request do
  let(:password) { "password123" }
  let(:user)     { create(:user, password:, password_confirmation: password, email: "security_test_#{SecureRandom.hex(4)}@example.com") }
  let(:list)     { create(:list, user:) }
  let!(:task)    { create(:task, list:, creator: user) }

  # ----------------------------
  # Helpers
  # ----------------------------
  def json
    JSON.parse(response.body) rescue {}
  end

  def post_json(path, params = {}, headers: {})
    post path,
         params: params,
         headers: headers.merge("CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json"),
         as: :json
  end

  def get_json(path, headers: {})
    get path, headers: headers.merge("ACCEPT" => "application/json")
  end

  def patch_json(path, params = {}, headers: {})
    patch path,
          params: params,
          headers: headers.merge("CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json"),
          as: :json
  end

  def delete_json(path, headers: {})
    delete path, headers: headers.merge("ACCEPT" => "application/json"), as: :json
  end

  # Always obtain real JWTs by hitting the real sign_in endpoint.
  # This ensures Devise-JWT/Warden generates whatever claims it needs.
  def auth_headers_for(u, password: "password123")
    post_json "/api/v1/auth/sign_in", { email: u.email, password: password }

    auth = response.headers["Authorization"]
    raise "Missing Authorization header in auth_headers_for" if auth.blank?

    {
      "Authorization" => auth,
      "ACCEPT" => "application/json"
    }
  end

  def expect_unauthorized!
    expect(response).to have_http_status(:unauthorized)
    # Don’t over-spec message text; just require a consistent error shape if present.
    if response.body.present?
      body = json
      if body.is_a?(Hash)
        # allow either {error:{...}} or {message:...} depending on your handler
        expect(body).to satisfy { |h| h.key?("error") || h.key?("message") || h.key?("errors") }
      end
    end
  end

  # ----------------------------
  # Tests
  # ----------------------------
  describe "Authentication / Authorization" do
    it "rejects access to protected endpoints without a token" do
      endpoints = %w[/api/v1/profile /api/v1/lists /api/v1/tasks /api/v1/devices]

      endpoints.each do |endpoint|
        get_json endpoint
        expect_unauthorized!
      end
    end

    it "rejects invalid Authorization headers" do
      invalid_headers = [
        { "Authorization" => "invalid_token" },
        { "Authorization" => "Bearer invalid_token" },
        { "Authorization" => "Bearer " },
        { "Authorization" => "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid" },
        { "Authorization" => "" }
      ]

      invalid_headers.each do |hdrs|
        get_json "/api/v1/profile", headers: hdrs
        expect_unauthorized!
      end
    end

    it "does not set session cookies for JWT-authenticated requests" do
      headers = auth_headers_for(user)

      get_json "/api/v1/profile", headers: headers
      expect(response).to have_http_status(:ok)

      # If you’re truly stateless JWT, you should not be setting session cookies.
      expect(response.headers["Set-Cookie"]).to be_nil
    end
  end

  describe "Cross-user access isolation" do
    let(:other_user) { create(:user, password:, password_confirmation: password) }
    let(:other_list) { create(:list, user: other_user) }
    let(:other_task) { create(:task, list: other_list, creator: other_user) }

    it "prevents user B from reading user A resources" do
      b_headers = auth_headers_for(other_user)

      # Depending on your design: return 404 (preferred to avoid enumeration) or 403.
      get_json "/api/v1/lists/#{list.id}", headers: b_headers
      expect([403, 404]).to include(response.status)

      get_json "/api/v1/lists/#{list.id}/tasks", headers: b_headers
      expect([403, 404]).to include(response.status)

      get_json "/api/v1/lists/#{list.id}/tasks/#{task.id}", headers: b_headers
      expect([403, 404]).to include(response.status)
    end

    it "allows the owner to read their own resources" do
      a_headers = auth_headers_for(user)

      get_json "/api/v1/lists/#{list.id}", headers: a_headers
      expect(response).to have_http_status(:ok)

      get_json "/api/v1/lists/#{list.id}/tasks", headers: a_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Input / request hardening" do
    it "handles malformed JSON with a 400" do
      headers = auth_headers_for(user)

      post "/api/v1/lists/#{list.id}/tasks",
           params: "not-json",
           headers: headers.merge("CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it "does not allow mass-assigning ownership on list creation" do
      headers = auth_headers_for(user)
      attacker = create(:user, password:, password_confirmation: password)

      # Try to create a list but force user_id to someone else.
      post_json "/api/v1/lists",
                { name: "hax", user_id: attacker.id, tasks_count: 999, list_shares_count: 999 },
                headers: headers

      # Either you reject (422/400) OR you ignore forbidden fields and create safely (201).
      expect([201, 400, 422]).to include(response.status)

      if response.status == 201
        created_id = json["id"] || json.dig("list", "id")
        expect(created_id).to be_present

        created = List.find(created_id)
        expect(created.user_id).to eq(user.id) # must be current_user, not attacker
        expect(created.tasks_count).to be >= 0
        expect(created.list_shares_count).to be >= 0
      end
    end
  end
end
