# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Devices API", type: :request do
  let(:user) { create(:user) }

  describe "POST /api/v1/devices" do
    let(:valid_params) do
      {
        device: {
          apns_token: "abc123def456789",
          bundle_id: "com.intentia.app",
          platform: "ios",
          device_name: "iPhone 15",
          os_version: "17.0",
          app_version: "1.0.0"
        }
      }
    end

    context "with valid params" do
      it "creates a device" do
        expect {
          auth_post "/api/v1/devices", user: user, params: valid_params
        }.to change(Device, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response["device"]["platform"]).to eq("ios")
        expect(json_response["device"]["bundle_id"]).to eq("com.intentia.app")
      end

      it "associates device with current user" do
        auth_post "/api/v1/devices", user: user, params: valid_params

        device = Device.last
        expect(device.user).to eq(user)
      end
    end

    context "with missing apns_token" do
      it "returns error" do
        auth_post "/api/v1/devices", user: user, params: { device: { platform: "ios", bundle_id: "com.test" } }

        expect(response.status).to be_in([400, 422])
      end
    end
  end

  describe "DELETE /api/v1/devices/:id" do
    let!(:device) { create(:device, user: user) }
    let(:other_user) { create(:user) }

    context "as device owner" do
      it "deletes the device" do
        auth_delete "/api/v1/devices/#{device.id}", user: user

        expect(response).to have_http_status(:no_content)
      end
    end

    context "as other user" do
      it "returns not found or forbidden" do
        auth_delete "/api/v1/devices/#{device.id}", user: other_user

        expect(response.status).to be_in([403, 404])
      end
    end
  end
end