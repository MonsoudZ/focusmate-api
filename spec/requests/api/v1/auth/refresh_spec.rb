# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Refresh", type: :request do
  describe "POST /api/v1/auth/refresh" do
    let(:user) { create(:user) }
    let(:pair) { Auth::TokenService.issue_pair(user) }
    let(:refresh_token) { pair[:refresh_token] }

    context "with a valid refresh token" do
      it "returns a new token pair" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json_response["token"]).to be_present
        expect(json_response["refresh_token"]).to be_present
        expect(json_response["user"]).to include("id" => user.id, "email" => user.email)
      end

      it "returns different tokens than the original" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(json_response["token"]).not_to eq(pair[:access_token])
        expect(json_response["refresh_token"]).not_to eq(refresh_token)
      end

      it "revokes the old refresh token" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        digest = Digest::SHA256.hexdigest(refresh_token)
        expect(RefreshToken.find_by(token_digest: digest)).to be_revoked
      end

      it "accepts the refresh token from X-Refresh-Token header" do
        post "/api/v1/auth/refresh",
             params: {}.to_json,
             headers: {
               "Content-Type" => "application/json",
               "X-Refresh-Token" => refresh_token
             }

        expect(response).to have_http_status(:ok)
        expect(json_response["refresh_token"]).to be_present
      end
    end

    context "with a reused (already-rotated) refresh token" do
      it "returns 401 within grace period but does NOT revoke family (race condition)" do
        # First rotation (valid)
        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        new_refresh_token = json_response["refresh_token"]

        # Replay the old token within grace period (simulates parallel request race)
        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response["error"]["code"]).to eq("token_already_refreshed")

        # The new token from the first rotation should NOT be revoked
        new_digest = Digest::SHA256.hexdigest(new_refresh_token)
        expect(RefreshToken.find_by(token_digest: new_digest)).not_to be_revoked
      end

      it "returns 401 and revokes entire family after grace period (real attack)" do
        # First rotation (valid)
        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        new_refresh_token = json_response["refresh_token"]

        # Replay the old token after grace period (real reuse attack)
        travel 15.seconds do
          post "/api/v1/auth/refresh",
               params: { refresh_token: refresh_token }.to_json,
               headers: { "Content-Type" => "application/json" }

          expect(response).to have_http_status(:unauthorized)
          expect(json_response["error"]["code"]).to eq("token_reused")
        end

        # The new token from the first rotation should be revoked
        new_digest = Digest::SHA256.hexdigest(new_refresh_token)
        expect(RefreshToken.find_by(token_digest: new_digest)).to be_revoked
      end
    end

    context "with an expired refresh token" do
      it "returns 401" do
        digest = Digest::SHA256.hexdigest(refresh_token)
        RefreshToken.find_by(token_digest: digest).update!(expires_at: 1.hour.ago)

        post "/api/v1/auth/refresh",
             params: { refresh_token: refresh_token }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an invalid refresh token" do
      it "returns 401" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: "bogus-token" }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a missing refresh token" do
      it "returns 401" do
        post "/api/v1/auth/refresh",
             params: {}.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with refresh token only in query string" do
      it "returns 401 and ignores query token transport" do
        post "/api/v1/auth/refresh?refresh_token=#{refresh_token}",
             params: {}.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response["error"]["code"]).to eq("token_invalid")
      end
    end

    context "with a non-scalar refresh token" do
      it "returns 401" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: { bad: "input" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a non-string scalar refresh token" do
      it "returns 401" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: 12345 }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response["error"]["code"]).to eq("token_invalid")
      end
    end

    context "with an excessively long refresh token" do
      it "returns 401" do
        post "/api/v1/auth/refresh",
             params: { refresh_token: "a" * 513 }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response["error"]["code"]).to eq("token_invalid")
      end
    end
  end
end
