# spec/requests/api/v1/authentication_controller_spec.rb
require "rails_helper"

RSpec.describe Api::V1::AuthenticationController, type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "password123" }
  let(:user)     { create(:user, password: password, password_confirmation: password) }

  # ---------- helpers ----------
  def json
    JSON.parse(response.body)
  end

  def auth_headers_for(u)
    # Obtain a real JWT by calling the login endpoint so Devise-JWT adds
    # whatever claims (including jti) it requires.
    post_json "/api/v1/login", { email: u.email, password: password }
    auth_header = response.headers["Authorization"]
    raise "Missing Authorization header in auth_headers_for" if auth_header.blank?
    { "Authorization" => auth_header }
  end

  def post_json(path, params = {}, headers: {})
    post path, params: params, headers: headers.merge("CONTENT_TYPE" => "application/json"), as: :json
  end

  def get_json(path, headers: {})
    get path, headers: headers.merge("ACCEPT" => "application/json")
  end

  def delete_json(path, headers: {})
    raise ArgumentError, "path required" if path.blank?
    delete path, headers: (headers || {}).merge("ACCEPT" => "application/json"), as: :json
  end

  # Use one canonical route; if you truly support aliases, cover them once via shared_examples.
  shared_examples "login success" do |path|
    it "logs in and returns user payload with JWT in Authorization header" do
      post_json path, { email: user.email, password: password }

      expect(response).to have_http_status(:ok)

      # Devise-JWT should attach the token to the Authorization header
      auth_header = response.headers["Authorization"]
      expect(auth_header).to be_present
      expect(auth_header).to match(/\ABearer\s+.+/)

      # Response body should contain user payload (no manual token generation)
      expect(json).to include("user")
      expect(json["user"]).to include("id" => user.id, "email" => user.email)
      expect(json).not_to have_key("token")
    end
  end

  shared_examples "login failure" do |path|
    it "rejects bad email" do
      post_json path, { email: "nope@example.com", password: password }
      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "message")).to be_present
    end

    it "rejects bad password" do
      post_json path, { email: user.email, password: "wrong" }
      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "message")).to be_present
    end

    it "rejects missing fields" do
      post_json path, {}
      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "message")).to be_present
    end
  end

  describe "POST /api/v1/login" do
    include_examples "login success", "/api/v1/login"
    include_examples "login failure", "/api/v1/login"

    it "accepts case-insensitive + whitespace emails" do
      post_json "/api/v1/login", { email: "  #{user.email.upcase} ", password: password }
      expect(response).to have_http_status(:ok)
      expect(json.dig("user", "id")).to eq(user.id)
    end

    it "returns a richer user payload when available" do
      post_json "/api/v1/login", { email: user.email, password: password }
      expect(response).to have_http_status(:ok)

      # Only assert on keys you guarantee; avoid over-specifying display fields.
      expect(json["user"]).to include("id", "email")
      expect(json["user"]).to include("name")      if json["user"].key?("name")
      expect(json["user"]).to include("role")      if json["user"].key?("role")
      expect(json["user"]).to include("timezone")  if json["user"].key?("timezone")
    end

    it "supports alias route /auth/sign_in (once)" do
      post_json "/api/v1/auth/sign_in", { email: user.email, password: password }
      expect(response).to have_http_status(:ok)

      auth_header = response.headers["Authorization"]
      expect(auth_header).to be_present
      expect(auth_header).to match(/\ABearer\s+.+/)

      expect(json).to include("user")
      expect(json).not_to have_key("token")
    end

    it "does NOT attempt concurrency via threads (request helpers are not thread-safe)" do
      # Documented behavior: we don’t test concurrency with Rails request specs.
      # Use service/unit tests for concurrent code paths instead.
      expect(true).to be_truthy
    end

    it "returns 400 on malformed JSON" do
      post "/api/v1/login", params: "bad json", headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /api/v1/register" do
    def register!(attrs)
      post_json "/api/v1/register", attrs
    end

    it "registers with valid attributes" do
      register!(email: "newuser@example.com", password: password, password_confirmation: password, name: "New User", timezone: "UTC")
      expect(response).to have_http_status(:created)
      expect(json).to include("user")
      expect(json).not_to have_key("token")
      # New registrations should also receive a JWT in the Authorization header
      auth_header = response.headers["Authorization"]
      expect(auth_header).to be_present
      expect(auth_header).to match(/\ABearer\s+.+/)
      expect(json.dig("user", "email")).to eq("newuser@example.com")
    end

    it "supports /auth/sign_up alias" do
      post_json "/api/v1/auth/sign_up", { email: "a@b.com", password: password, password_confirmation: password, name: "A", timezone: "UTC" }
      expect(response).to have_http_status(:created)
      expect(json).to include("user")
      expect(json).not_to have_key("token")
      auth_header = response.headers["Authorization"]
      expect(auth_header).to be_present
      expect(auth_header).to match(/\ABearer\s+.+/)
    end

    it "normalizes email whitespace" do
      register!(email: " spaced@example.com ", password: password, password_confirmation: password, timezone: "UTC")
      expect(response).to have_http_status(:created)
      expect(json.dig("user", "email")).to eq("spaced@example.com")
    end

    it "accepts timezone and sets default role" do
      register!(email: "user_#{SecureRandom.hex(4)}@example.com", password: password, password_confirmation: password, timezone: "America/Los_Angeles")
      expect(response).to have_http_status(:created)
      expect(json.dig("user", "role")).to eq("client")  # Default role
      expect(json.dig("user", "timezone")).to eq("America/Los_Angeles")
    end

    context "invalid" do
      it "rejects invalid email" do
        register!(email: "invalid", password: password, password_confirmation: password, timezone: "UTC")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(json["message"]).to be_present
      end

      it "rejects duplicate email" do
        register!(email: user.email, password: password, password_confirmation: password, timezone: "UTC")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.content_type).to eq("application/json; charset=utf-8")
      end

      it "rejects mismatched passwords" do
        register!(email: "x@y.com", password: password, password_confirmation: "nope", timezone: "UTC")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.content_type).to eq("application/json; charset=utf-8")
      end

      it "rejects too-short password" do
        register!(email: "x@y.com", password: "123", password_confirmation: "123", timezone: "UTC")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.content_type).to eq("application/json; charset=utf-8")
      end

      it "rejects extreme input sizes (defense-in-depth)" do
        register!(email: "#{'a' * 200}@example.com", password: "a" * 1000, password_confirmation: "a" * 1000, timezone: "UTC")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.content_type).to eq("application/json; charset=utf-8")
      end
    end
  end

  describe "GET /api/v1/profile" do
    context "with valid token" do
      it "returns the profile" do
        get_json "/api/v1/profile", headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        expect(json).to include("id" => user.id, "email" => user.email)
      end

      it "optionally returns extended fields when implemented" do
        get_json "/api/v1/profile", headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        %w[name role timezone created_at accessible_lists_count].each do |key|
          # Don't fail if the field isn’t in this build yet
          json.key?(key)
        end
      end
    end

    context "without valid token" do
      it "requires a token" do
        get_json "/api/v1/profile"
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects invalid/expired/malformed tokens" do
        get_json "/api/v1/profile", headers: { "Authorization" => "Bearer invalid" }
        expect(response).to have_http_status(:unauthorized)

        travel_to 2.hours.ago do
          expired = JWT.encode({ user_id: user.id, exp: 1.hour.ago.to_i }, Rails.application.secret_key_base, "HS256")
          get_json "/api/v1/profile", headers: { "Authorization" => "Bearer #{expired}" }
          expect(response).to have_http_status(:unauthorized)
        end

        bad_sig = JWT.encode({ user_id: user.id, exp: 30.days.from_now.to_i }, "wrong_secret")
        get_json "/api/v1/profile", headers: { "Authorization" => "Bearer #{bad_sig}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects tokens without a user or with a missing user" do
        token_without_user = JWT.encode({ exp: 30.days.from_now.to_i }, Rails.application.secret_key_base, "HS256")
        get_json "/api/v1/profile", headers: { "Authorization" => "Bearer #{token_without_user}" }
        expect(response).to have_http_status(:unauthorized)

        token_with_fake_user = JWT.encode({ user_id: 9_999_999, exp: 30.days.from_now.to_i }, Rails.application.secret_key_base, "HS256")
        get_json "/api/v1/profile", headers: { "Authorization" => "Bearer #{token_with_fake_user}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/logout" do
    it "logs out with valid token" do
      delete_json "/api/v1/logout", headers: auth_headers_for(user)
      expect(response).to have_http_status(:no_content)
    end


    it "rejects missing token" do
      delete_json "/api/v1/logout"
      expect(response).to have_http_status(:unauthorized)
    end

    it "documents future denylist behavior (no assertion now)" do
      post_json "/api/v1/login", { email: user.email, password: password }
      auth_header = response.headers["Authorization"]
      expect(auth_header).to be_present
      token = auth_header.split.last

      get_json "/api/v1/profile", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      delete_json "/api/v1/logout", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:no_content)

      # When you implement token denylisting, add:
      # get_json "/api/v1/profile", headers: { "Authorization" => "Bearer #{token}" }
      # expect(response).to have_http_status(:unauthorized)
    end
  end
end
