# frozen_string_literal: true

require "rails_helper"

RSpec.describe WellKnownController, type: :request do
  describe "GET /.well-known/apple-app-site-association" do
    it "returns the apple app site association JSON" do
      get "/.well-known/apple-app-site-association"

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["applinks"]["apps"]).to eq([])
      expect(json["applinks"]["details"]).to be_an(Array)
      expect(json["applinks"]["details"].first["paths"]).to include("/invite/*")
    end

    it "includes the configured app ID" do
      get "/.well-known/apple-app-site-association"

      json = response.parsed_body
      app_id = json["applinks"]["details"].first["appID"]
      expect(app_id).to be_present
    end
  end
end
