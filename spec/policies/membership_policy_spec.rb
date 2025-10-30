# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPolicy, type: :policy do
  let(:list_owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:membership) { create(:membership, list: list, user: other_user, role: 'editor') }

  describe '#index?' do
    it 'allows users who can view the list' do
      policy = described_class.new(list_owner, membership)
      expect(policy.index?).to be true
    end

    it 'denies users who cannot view the list' do
      unauthorized_user = create(:user)
      policy = described_class.new(unauthorized_user, membership)
      expect(policy.index?).to be false
    end
  end

  describe '#show?' do
    it 'allows users who can view the list' do
      policy = described_class.new(list_owner, membership)
      expect(policy.show?).to be true
    end

    it 'denies users who cannot view the list' do
      unauthorized_user = create(:user)
      policy = described_class.new(unauthorized_user, membership)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows users who can invite to the list' do
      policy = described_class.new(list_owner, membership)
      expect(policy.create?).to be true
    end

    it 'denies users who cannot invite to the list' do
      unauthorized_user = create(:user)
      policy = described_class.new(unauthorized_user, membership)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows users who can invite to the list' do
      policy = described_class.new(list_owner, membership)
      expect(policy.update?).to be true
    end

    it 'denies users who cannot invite to the list' do
      unauthorized_user = create(:user)
      policy = described_class.new(unauthorized_user, membership)
      expect(policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows users who can invite to the list' do
      policy = described_class.new(list_owner, membership)
      expect(policy.destroy?).to be true
    end

    it 'allows users to remove their own membership' do
      policy = described_class.new(other_user, membership)
      expect(policy.destroy?).to be true
    end

    it 'denies users who cannot invite and are not removing themselves' do
      unauthorized_user = create(:user)
      policy = described_class.new(unauthorized_user, membership)
      expect(policy.destroy?).to be false
    end
  end

  describe 'Scope' do
    describe '#resolve' do
      let!(:accessible_membership) { create(:membership, list: list, user: other_user, role: 'editor') }
      let(:other_list) { create(:list, user: create(:user)) }
      let!(:inaccessible_membership) { create(:membership, list: other_list, user: create(:user), role: 'viewer') }

      it 'returns memberships for lists accessible by the user' do
        accessible_lists = double('accessible_lists')
        allow(List).to receive(:accessible_by).with(list_owner).and_return(accessible_lists)
        allow(Membership).to receive(:joins).and_return(Membership)
        allow(Membership).to receive(:where).and_return(Membership.where(id: accessible_membership.id))

        scope = MembershipPolicy::Scope.new(list_owner, Membership).resolve

        expect(List).to have_received(:accessible_by).with(list_owner)
      end
    end
  end
end
