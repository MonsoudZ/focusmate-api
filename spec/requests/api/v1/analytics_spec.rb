# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analytics API", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe "POST /api/v1/analytics/app_opened" do
    context "when authenticated" do
      it "tracks app opened event" do
        expect {
          perform_enqueued_jobs do
            auth_post "/api/v1/analytics/app_opened", user: user, params: { platform: "ios", version: "1.0.0" }
          end
        }.to change(AnalyticsEvent, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it "records platform and version" do
        perform_enqueued_jobs do
          auth_post "/api/v1/analytics/app_opened", user: user, params: { platform: "ios", version: "1.0.0" }
        end

        event = AnalyticsEvent.last
        expect(event.event_type).to eq("app_opened")
        expect(event.user).to eq(user)
      end

      it "defaults platform to ios" do
        auth_post "/api/v1/analytics/app_opened", user: user, params: {}

        expect(response).to have_http_status(:ok)
      end

      it "ignores non-scalar platform and version params" do
        perform_enqueued_jobs do
          auth_post "/api/v1/analytics/app_opened",
                    user: user,
                    params: { platform: { bad: "input" }, version: [ "1.0.0" ] }
        end

        expect(response).to have_http_status(:ok)
        event = AnalyticsEvent.last
        expect(event.metadata["platform"]).to eq("ios")
        expect(event.metadata["version"]).to be_nil
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
