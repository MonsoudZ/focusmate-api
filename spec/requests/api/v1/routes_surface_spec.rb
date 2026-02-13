# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API surface", type: :request do
  describe "deleted routes should not be accessible" do
    it "does not expose /items" do
      get "/api/v1/items"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose legacy PUT /devices/token" do
      put "/api/v1/devices/token"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose nested /items under lists" do
      get "/api/v1/lists/1/items"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose global task action routes (only nested under lists)" do
      post "/api/v1/tasks/1/complete"
      expect(response.status).to be_between(404, 410).inclusive

      post "/api/v1/tasks/1/reassign"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose devise html-form routes for API auth" do
      get "/api/v1/auth/sign_in"
      expect(response.status).to be_between(404, 410).inclusive

      get "/api/v1/auth/sign_up/sign_up"
      expect(response.status).to be_between(404, 410).inclusive

      get "/api/v1/auth/password/new"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose unsupported sign_up verbs" do
      patch "/api/v1/auth/sign_up"
      expect(response.status).to be_between(404, 410).inclusive

      put "/api/v1/auth/sign_up"
      expect(response.status).to be_between(404, 410).inclusive

      delete "/api/v1/auth/sign_up"
      expect(response.status).to be_between(404, 410).inclusive
    end

    it "does not expose unused framework routes" do
      get "/rails/action_mailbox/relay/inbound_emails"
      expect(response.status).to be_between(404, 410).inclusive

      get "/rails/active_storage/blobs/redirect/abc/file.txt"
      expect(response.status).to be_between(404, 410).inclusive
    end
  end

  describe "kept routes should be accessible" do
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

    it "exposes devices create/destroy routes" do
      post "/api/v1/devices"
      expect(response.status).not_to be_between(404, 410).inclusive

      delete "/api/v1/devices/1"
      expect(response.status).not_to be_between(404, 410).inclusive
    end

    it "exposes lists and nested tasks routes" do
      get "/api/v1/lists"
      expect(response.status).not_to be_between(404, 410).inclusive

      # nested tasks exist (even though they will likely 401/404 depending on auth/list existence)
      post "/api/v1/lists/1/tasks"
      expect(response.status).not_to be_between(404, 410).inclusive

      patch "/api/v1/lists/1/tasks/1/complete"
      expect(response.status).not_to be_between(404, 410).inclusive
    end

    it "exposes memberships routes under lists" do
      get "/api/v1/lists/1/memberships"
      expect(response.status).not_to be_between(404, 410).inclusive

      post "/api/v1/lists/1/memberships"
      expect(response.status).not_to be_between(404, 410).inclusive
    end
  end
end
