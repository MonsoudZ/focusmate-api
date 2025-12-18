  # frozen_string_literal: true

  require "rails_helper"

  RSpec.describe UserPreferencesService do
    let(:user) { create(:user) }

    describe "#update!" do
      context "with valid preferences" do
        it "updates user preferences with a hash" do
          preferences = { "theme" => "dark", "notifications" => true }

          result = described_class.new(user: user, preferences: preferences).update!

          expect(result).to eq(user)
          expect(user.reload.preferences).to include("theme" => "dark", "notifications" => true)
        end

        it "accepts ActionController::Parameters" do
          params = ActionController::Parameters.new(preferences: { theme: "dark", notifications: true })

          result = described_class.new(user: user, preferences: params[:preferences]).update!

          expect(result).to eq(user)
          expect(user.reload.preferences).to include("theme" => "dark", "notifications" => true)
        end
      end

      context "with invalid preferences" do
        it "raises ValidationError for non-hash input" do
          expect {
            described_class.new(user: user, preferences: "invalid").update!
          }.to raise_error(
            UserPreferencesService::ValidationError,
            "Preferences must be a JSON object"
          )
        end

        it "raises ValidationError when update fails" do
          fake_user = instance_double(
            User,
            update: false,
            errors: instance_double(ActiveModel::Errors, full_messages: [ "boom" ])
          )

          expect {
            described_class.new(user: fake_user, preferences: { "k" => "v" }).update!
          }.to raise_error(UserPreferencesService::ValidationError, "Failed to update preferences")
        end
      end
    end
  end
