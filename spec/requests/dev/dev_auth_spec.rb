require "rails_helper"

RSpec.describe "Dev auth endpoints", :dev_only, type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/test-profile" do
    it "returns user profile" do
      get "/api/v1/test-profile"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("id", "email", "name", "role", "timezone")
    end
  end

  describe "GET /api/v1/test-lists" do
    it "returns user lists" do
      get "/api/v1/test-lists"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_an(Array)
    end
  end

  describe "DELETE /api/v1/test-logout" do
    it "returns no content" do
      delete "/api/v1/test-logout"
      expect(response).to have_http_status(:no_content)
    end
  end
end
