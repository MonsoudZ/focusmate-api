# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "API surface", type: :request do
  describe "deleted routes should not be accessible" do
    it "does not expose /items" do
      get "/api/v1/items"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose PUT /devices/token" do
      put "/api/v1/devices/token"
      expect(response.status).to be_between(401, 410).inclusive
    end

    it "does not expose nested /items under lists" do
      get "/api/v1/lists/1/items"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose POST variants of task actions globally" do
      post "/api/v1/tasks/1/complete"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose POST variants of task reassign globally" do
      post "/api/v1/tasks/1/reassign"
      expect(response.status).to be_between(404, 410).inclusive
    end
  end

  describe "kept routes should be accessible" do
    it "exposes PATCH /users/device_token" do
      # This should be a valid route (even if it returns 401 without auth)
      patch "/api/v1/users/device_token"
      expect(response.status).not_to be_between(404, 410).inclusive
    end

    it "exposes /auth/sign_in" do
      post "/api/v1/auth/sign_in"
      expect(response.status).not_to be_between(404, 410).inclusive
    end

    it "exposes /auth/sign_up" do
      post "/api/v1/auth/sign_up"
      expect(response.status).not_to be_between(404, 410).inclusive
    end

    it "exposes /auth/sign_out" do
      delete "/api/v1/auth/sign_out"
      expect(response.status).not_to be_between(404, 410).inclusive
    end
  end
end
