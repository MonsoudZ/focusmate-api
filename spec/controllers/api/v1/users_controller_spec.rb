require "rails_helper"

RSpec.describe Api::V1::UsersController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:headers) { auth_headers(user) }

  describe "POST /api/v1/users/location" do
    it "requires auth" do
      post "/api/v1/users/location", params: { latitude: 40.7, longitude: -74.0 }
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates user location and creates a history row" do
      post "/api/v1/users/location",
           params: { latitude: 40.7128, longitude: -74.0060 },
           headers: headers

      expect(response).to have_http_status(:ok)

      user.reload
      expect(user.latitude).to eq(40.7128)
      expect(user.longitude).to eq(-74.0060)
      expect(user.location_updated_at).to be_present

      loc = UserLocation.order(:created_at).last
      expect(loc.user_id).to eq(user.id)
      expect(loc.latitude).to eq(40.7128)
      expect(loc.longitude).to eq(-74.0060)
    end

    it "returns 400 when latitude/longitude missing" do
      post "/api/v1/users/location", params: { latitude: 40.7 }, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 422 for invalid coordinates" do
      post "/api/v1/users/location",
           params: { latitude: 91.0, longitude: -74.0 },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/users/preferences" do
    it "requires auth" do
      patch "/api/v1/users/preferences", params: { preferences: { notifications: true } }
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates preferences (hash)" do
      patch "/api/v1/users/preferences",
            params: { preferences: { notifications: true, timezone: "America/New_York" } },
            headers: headers

      expect(response).to have_http_status(:ok)

      user.reload
      expect(user.preferences["notifications"]).to eq(true).or(eq("true")) # depending on your implementation
      expect(user.preferences["timezone"]).to eq("America/New_York")
    end

    it "treats missing preferences as {}" do
      patch "/api/v1/users/preferences", params: {}, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  # IMPORTANT: make this match your *current* routes
  def auth_headers(user, password: "password123")
    post "/api/v1/auth/sign_in",
         params: { authentication: { email: user.email, password: password } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    raise "Missing Authorization header in auth_headers" if token.blank?

    { "Authorization" => token, "ACCEPT" => "application/json" }
  end
end
