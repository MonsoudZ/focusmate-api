# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notification Preferences API", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/notification_preference" do
    context "when authenticated" do
      it "auto-creates preference with defaults when none exists" do
        expect { auth_get "/api/v1/notification_preference", user: user }
          .to change(NotificationPreference, :count).by(1)

        expect(response).to have_http_status(:ok)
        pref = json_response["notification_preference"]
        expect(pref["nudge_enabled"]).to be true
        expect(pref["task_assigned_enabled"]).to be true
        expect(pref["list_joined_enabled"]).to be true
        expect(pref["task_reminder_enabled"]).to be true
        expect(pref["updated_at"]).to be_present
      end

      it "returns existing preference" do
        create(:notification_preference, user: user, nudge_enabled: false)

        auth_get "/api/v1/notification_preference", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["notification_preference"]["nudge_enabled"]).to be false
      end

      it "does not expose id or user_id" do
        auth_get "/api/v1/notification_preference", user: user

        pref = json_response["notification_preference"]
        expect(pref).not_to have_key("id")
        expect(pref).not_to have_key("user_id")
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/notification_preference"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/notification_preference" do
    context "when authenticated" do
      it "updates existing preference" do
        create(:notification_preference, user: user)

        auth_patch "/api/v1/notification_preference", user: user,
          params: { nudge_enabled: false, task_reminder_enabled: false }

        expect(response).to have_http_status(:ok)
        pref = json_response["notification_preference"]
        expect(pref["nudge_enabled"]).to be false
        expect(pref["task_assigned_enabled"]).to be true
        expect(pref["task_reminder_enabled"]).to be false
      end

      it "auto-creates and updates when no preference exists" do
        expect {
          auth_patch "/api/v1/notification_preference", user: user,
            params: { nudge_enabled: false }
        }.to change(NotificationPreference, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response["notification_preference"]["nudge_enabled"]).to be false
      end

      it "supports partial updates" do
        create(:notification_preference, user: user, nudge_enabled: false)

        auth_patch "/api/v1/notification_preference", user: user,
          params: { task_assigned_enabled: false }

        expect(response).to have_http_status(:ok)
        pref = json_response["notification_preference"]
        expect(pref["nudge_enabled"]).to be false
        expect(pref["task_assigned_enabled"]).to be false
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        patch "/api/v1/notification_preference",
          params: { nudge_enabled: false }.to_json,
          headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
