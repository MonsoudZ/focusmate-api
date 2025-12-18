# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Devices", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  def json
    JSON.parse(response.body) if response.body.present?
  end

  def auth_headers(user, password: "password123")
    post "/api/v1/login",
         params: {
           authentication: {
             email: user.email,
             password: password
           }
         }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }

    body = JSON.parse(response.body)
    token = body["token"] || body["jwt"]

    raise "Missing token in login response" if token.blank?

    { "Authorization" => "Bearer #{token}", "ACCEPT" => "application/json" }
  end

  let(:headers) { auth_headers(user) }

  describe "POST /api/v1/devices" do
    let(:payload) do
      {
        device: {
          apns_token: "apns_#{SecureRandom.hex(12)}",
          device_name: "iPhone",
          os_version: "17.3",
          app_version: "1.2.3",
          timezone: "America/New_York"
        }
      }
    end

    it "creates or upserts a device for the current user" do
      expect {
        post "/api/v1/devices", params: payload, headers: headers
      }.to change(Device, :count).by(1)

      expect(response).to have_http_status(:created)

      returned = json["device"]
      expect(returned).to be_present
      expect(returned["apns_token"]).to eq(payload[:device][:apns_token])

      device = Device.find(returned["id"])
      expect(device.user_id).to eq(user.id)
    end

    it "is idempotent by apns_token" do
      post "/api/v1/devices", params: payload, headers: headers
      first_id = json.dig("device", "id")

      expect {
        post "/api/v1/devices", params: payload, headers: headers
      }.not_to change(Device, :count)

      expect(json.dig("device", "id")).to eq(first_id)
    end

    it "requires authentication" do
      post "/api/v1/devices", params: payload
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/devices/:id" do
    let!(:device) do
      Device.create!(
        user: user,
        apns_token: "apns_#{SecureRandom.hex(10)}",
        device_name: "iPhone",
        os_version: "17.0",
        app_version: "1.0.0",
        timezone: "America/New_York"
      )
    end

    it "deletes the user's device" do
      expect {
        delete "/api/v1/devices/#{device.id}", headers: headers
      }.to change(Device, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "does not allow deleting another user's device" do
      other_device = Device.create!(
        user: other_user,
        apns_token: "apns_#{SecureRandom.hex(10)}",
        device_name: "Pixel",
        os_version: "14",
        app_version: "1.0.0",
        timezone: "America/New_York"
      )

      delete "/api/v1/devices/#{other_device.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      delete "/api/v1/devices/#{device.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
