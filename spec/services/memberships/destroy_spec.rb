# frozen_string_literal: true

require "rails_helper"

RSpec.describe Memberships::Destroy do
  describe ".call!" do
    let(:owner) { create(:user) }
    let(:list) { create(:list, user: owner) }
    let(:member) { create(:user) }

    context "when destroying a non-owner membership" do
      let!(:membership) { create(:membership, list: list, user: member, role: "editor") }

      it "destroys the membership" do
        expect {
          described_class.call!(membership: membership)
        }.to change(Membership, :count).by(-1)
      end

      it "returns the destroyed membership" do
        result = described_class.call!(membership: membership)

        expect(result).to eq(membership)
        expect(result).to be_destroyed
      end
    end

    context "when trying to remove the list owner" do
      let!(:owner_membership) { create(:membership, list: list, user: owner, role: "editor") }

      it "raises Conflict" do
        expect {
          described_class.call!(membership: owner_membership)
        }.to raise_error(ApplicationError::Conflict, "Cannot remove the list owner")
      end

      it "does not destroy the membership" do
        expect {
          begin
            described_class.call!(membership: owner_membership)
          rescue ApplicationError::Conflict
            # expected
          end
        }.not_to change(Membership, :count)
      end
    end
  end
end
