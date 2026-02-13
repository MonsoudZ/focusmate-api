# frozen_string_literal: true

require "rails_helper"

RSpec.describe Devise::Mailer, type: :mailer do
  describe "#reset_password_instructions" do
    let(:user) { create(:user, email: "test@example.com") }
    let(:token) { "abc123resettoken" }
    let(:mail) { described_class.reset_password_instructions(user, token) }

    it "sends to the user's email" do
      expect(mail.to).to eq([ user.email ])
    end

    it "sets the correct subject" do
      expect(mail.subject).to eq("Reset password instructions")
    end

    it "includes the frontend reset URL with token in the text body" do
      expected_url = "http://localhost:3000/reset-password?token=#{token}"
      expect(mail.text_part.body.to_s).to include(expected_url)
    end

    it "includes the frontend reset URL with token in the HTML body" do
      expected_url = "http://localhost:3000/reset-password?token=#{token}"
      expect(mail.html_part.body.to_s).to include(expected_url)
    end

    context "with APP_WEB_BASE configured" do
      around do |example|
        original = ENV["APP_WEB_BASE"]
        ENV["APP_WEB_BASE"] = "https://app.intentia.com"
        example.run
      ensure
        ENV["APP_WEB_BASE"] = original
      end

      it "uses APP_WEB_BASE in the reset URL" do
        expected_url = "https://app.intentia.com/reset-password?token=#{token}"
        expect(mail.text_part.body.to_s).to include(expected_url)
      end
    end
  end
end
