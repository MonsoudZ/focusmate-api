# frozen_string_literal: true

require "rails_helper"

RSpec.describe Memberships::Update do
  describe ".call!" do
    let(:owner) { create(:user) }
    let(:list) { create(:list, user: owner) }
    let(:member) { create(:user) }
    let(:actor) { owner }
    let!(:membership) { create(:membership, :viewer, list: list, user: member) }

    context "when updating role to editor" do
      it "updates the membership role" do
        result = described_class.call!(membership: membership, actor: actor, role: "editor")

        expect(result.role).to eq("editor")
      end

      it "persists the change" do
        described_class.call!(membership: membership, actor: actor, role: "editor")

        expect(membership.reload.role).to eq("editor")
      end

      it "returns the updated membership" do
        result = described_class.call!(membership: membership, actor: actor, role: "editor")

        expect(result).to eq(membership)
      end
    end

    context "when updating role to viewer" do
      let!(:membership) { create(:membership, :editor, list: list, user: member) }

      it "updates the membership role" do
        result = described_class.call!(membership: membership, actor: actor, role: "viewer")

        expect(result.role).to eq("viewer")
      end

      it "persists the change" do
        described_class.call!(membership: membership, actor: actor, role: "viewer")

        expect(membership.reload.role).to eq("viewer")
      end
    end

    context "when role is blank" do
      it "raises BadRequest with empty string" do
        expect {
          described_class.call!(membership: membership, actor: actor, role: "")
        }.to raise_error(Memberships::Update::BadRequest, "role is required")
      end

      it "raises BadRequest with nil" do
        expect {
          described_class.call!(membership: membership, actor: actor, role: nil)
        }.to raise_error(Memberships::Update::BadRequest, "role is required")
      end

      it "raises BadRequest with whitespace-only string" do
        expect {
          described_class.call!(membership: membership, actor: actor, role: "   ")
        }.to raise_error(Memberships::Update::BadRequest, "role is required")
      end
    end

    context "when role is invalid" do
      it "raises BadRequest for unrecognized role" do
        expect {
          described_class.call!(membership: membership, actor: actor, role: "admin")
        }.to raise_error(Memberships::Update::BadRequest, "Invalid role")
      end

      it "raises BadRequest for owner role" do
        expect {
          described_class.call!(membership: membership, actor: actor, role: "owner")
        }.to raise_error(Memberships::Update::BadRequest, "Invalid role")
      end
    end
  end
end
