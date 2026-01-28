# frozen_string_literal: true

require "rails_helper"

RSpec.describe Memberships::Create do
  describe ".call!" do
    let(:owner) { create(:user) }
    let(:list) { create(:list, user: owner) }
    let(:inviter) { owner }
    let(:target_user) { create(:user) }

    context "with valid params using email identifier" do
      it "creates a membership" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: target_user.email,
            role: "viewer"
          )
        }.to change(Membership, :count).by(1)
      end

      it "returns the created membership" do
        result = described_class.call!(
          list: list,
          inviter: inviter,
          user_identifier: target_user.email,
          role: "editor"
        )

        expect(result).to be_a(Membership)
        expect(result).to be_persisted
        expect(result.user).to eq(target_user)
        expect(result.list).to eq(list)
        expect(result.role).to eq("editor")
      end
    end

    context "role defaulting" do
      it "defaults role to viewer when role is empty string" do
        result = described_class.call!(
          list: list,
          inviter: inviter,
          user_identifier: target_user.email,
          role: ""
        )

        expect(result.role).to eq("viewer")
      end

      it "defaults role to viewer when role is nil" do
        result = described_class.call!(
          list: list,
          inviter: inviter,
          user_identifier: target_user.email,
          role: nil
        )

        expect(result.role).to eq("viewer")
      end
    end

    context "finding user by email" do
      it "finds the user by email address" do
        result = described_class.call!(
          list: list,
          inviter: inviter,
          user_identifier: target_user.email,
          role: "viewer"
        )

        expect(result.user).to eq(target_user)
      end
    end

    context "finding user by numeric ID" do
      it "finds the user by ID" do
        result = described_class.call!(
          list: list,
          inviter: inviter,
          user_identifier: target_user.id.to_s,
          role: "viewer"
        )

        expect(result.user).to eq(target_user)
      end
    end

    context "when user_identifier is blank" do
      it "raises BadRequest with empty string" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: "",
            role: "viewer"
          )
        }.to raise_error(Memberships::Create::BadRequest, "user_identifier is required")
      end

      it "raises BadRequest with nil" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: nil,
            role: "viewer"
          )
        }.to raise_error(Memberships::Create::BadRequest, "user_identifier is required")
      end
    end

    context "when role is invalid" do
      it "raises BadRequest for unrecognized role" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: target_user.email,
            role: "admin"
          )
        }.to raise_error(Memberships::Create::BadRequest, "Invalid role")
      end
    end

    context "when user is not found" do
      it "raises NotFound for non-existent email" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: "nonexistent@example.com",
            role: "viewer"
          )
        }.to raise_error(Memberships::Create::NotFound, "User not found")
      end

      it "raises NotFound for non-existent ID" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: "999999999",
            role: "viewer"
          )
        }.to raise_error(Memberships::Create::NotFound, "User not found")
      end
    end

    context "when inviting self" do
      it "raises Conflict" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: inviter.email,
            role: "viewer"
          )
        }.to raise_error(Memberships::Create::Conflict, "Cannot invite yourself")
      end
    end

    context "when user is already a member" do
      before do
        create(:membership, list: list, user: target_user, role: "viewer")
      end

      it "raises Conflict" do
        expect {
          described_class.call!(
            list: list,
            inviter: inviter,
            user_identifier: target_user.email,
            role: "editor"
          )
        }.to raise_error(Memberships::Create::Conflict, "User is already a member of this list")
      end
    end
  end
end
