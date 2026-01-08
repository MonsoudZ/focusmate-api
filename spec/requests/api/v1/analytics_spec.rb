# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analytics API", type: :request do
  let(:user) { create(:user) }

  describe "POST /api/v1/analytics/app_opened" do
    context "when authenticated" do
      it "tracks app opened event" do
        expect {
          auth_post "/api/v1/analytics/app_opened", user: user, params: { platform: "ios", version: "1.0.0" }
        }.to change(AnalyticsEvent, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it "records platform and version" do
        auth_post "/api/v1/analytics/app_opened", user: user, params: { platform: "ios", version: "1.0.0" }

        event = AnalyticsEvent.last
        expect(event.event_type).to eq("app_opened")
        expect(event.user).to eq(user)
      end

      it "defaults platform to ios" do
        auth_post "/api/v1/analytics/app_opened", user: user, params: {}

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        post "/api/v1/analytics/app_opened",
             params: { platform: "ios" }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end