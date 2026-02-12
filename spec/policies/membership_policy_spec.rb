# frozen_string_literal: true

require "rails_helper"

RSpec.describe MembershipPolicy, type: :policy do
  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:stranger) { create(:user) }

  let(:owned_list) { create(:list, user: owner) }
  let(:stranger_list) { create(:list, user: stranger) }

  let!(:owned_list_membership) { owned_list.memberships.create!(user: member, role: "viewer") }
  let!(:stranger_list_membership) { stranger_list.memberships.create!(user: create(:user), role: "viewer") }

  describe "Scope" do
    describe "#resolve" do
      context "as list owner" do
        subject { described_class::Scope.new(owner, Membership.all).resolve }

        it "includes memberships from owned lists" do
          expect(subject).to include(owned_list_membership)
        end

        it "excludes memberships from lists user cannot access" do
          expect(subject).not_to include(stranger_list_membership)
        end
      end

      context "as list member" do
        subject { described_class::Scope.new(member, Membership.all).resolve }

        it "includes memberships from lists user is a member of" do
          expect(subject).to include(owned_list_membership)
        end

        it "excludes memberships from lists user cannot access" do
          expect(subject).not_to include(stranger_list_membership)
        end
      end

      context "as stranger" do
        subject { described_class::Scope.new(stranger, Membership.all).resolve }

        it "includes memberships from owned lists" do
          expect(subject).to include(stranger_list_membership)
        end

        it "excludes memberships from lists user cannot access" do
          expect(subject).not_to include(owned_list_membership)
        end
      end

      it "does not leak all memberships" do
        # This is the critical test - the old scope returned scope.all
        all_memberships = Membership.all.count
        scoped_for_owner = described_class::Scope.new(owner, Membership.all).resolve.count
        scoped_for_stranger = described_class::Scope.new(stranger, Membership.all).resolve.count

        # Each user should only see memberships from their accessible lists
        expect(scoped_for_owner).to be < all_memberships
        expect(scoped_for_stranger).to be < all_memberships
      end
    end
  end

  describe "permissions" do
    let(:membership) { owned_list_membership }

    describe "#show?" do
      it "allows list owner to view membership" do
        policy = described_class.new(owner, owned_list_membership)
        expect(policy.show?).to be true
      end

      it "allows list member to view membership" do
        policy = described_class.new(member, owned_list_membership)
        expect(policy.show?).to be true
      end

      it "denies stranger from viewing membership" do
        policy = described_class.new(stranger, owned_list_membership)
        expect(policy.show?).to be false
      end
    end

    describe "#create?" do
      it "allows list owner to create memberships" do
        policy = described_class.new(owner, membership)
        expect(policy.create?).to be true
      end

      it "denies non-owner from creating memberships" do
        policy = described_class.new(member, membership)
        expect(policy.create?).to be false
      end
    end

    describe "#update?" do
      it "allows list owner to update memberships" do
        policy = described_class.new(owner, membership)
        expect(policy.update?).to be true
      end

      it "denies non-owner from updating memberships" do
        policy = described_class.new(member, membership)
        expect(policy.update?).to be false
      end
    end

    describe "#destroy?" do
      it "allows list owner to destroy memberships" do
        policy = described_class.new(owner, membership)
        expect(policy.destroy?).to be true
      end

      it "denies non-owner from destroying memberships" do
        policy = described_class.new(member, membership)
        expect(policy.destroy?).to be false
      end
    end
  end
end
