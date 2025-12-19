# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ListPolicy, type: :policy do
  let(:list_owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }

  describe '#index?' do
    it 'allows any authenticated user' do
      policy = described_class.new(other_user, List)
      expect(policy.index?).to be true
    end
  end

  describe '#show?' do
    it 'allows the list owner' do
      policy = described_class.new(list_owner, list)
      expect(policy.show?).to be true
    end

    it 'denies access to users without view access' do
      policy = described_class.new(other_user, list)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows any authenticated user' do
      policy = described_class.new(other_user, List)
      expect(policy.create?).to be true
    end
  end

  describe '#update?' do
    it 'allows the list owner' do
      policy = described_class.new(list_owner, list)
      expect(policy.update?).to be true
    end

    it 'denies access to users without edit access' do
      policy = described_class.new(other_user, list)
      expect(policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the list owner' do
      policy = described_class.new(list_owner, list)
      expect(policy.destroy?).to be true
    end

    it 'denies access to other users' do
      policy = described_class.new(other_user, list)
      expect(policy.destroy?).to be false
    end
  end

  describe '#manage_memberships?' do
    it 'allows the list owner' do
      policy = described_class.new(list_owner, list)
      expect(policy.manage_memberships?).to be true
    end

    it 'denies access to non-owners' do
      policy = described_class.new(other_user, list)
      expect(policy.manage_memberships?).to be false
    end
  end

  describe 'Scope' do
    describe '#resolve' do
      it 'returns lists owned by the user' do
        owned_list = create(:list, user: list_owner)
        other_list = create(:list, user: other_user)

        scope = ListPolicy::Scope.new(list_owner, List).resolve

        expect(scope).to include(owned_list)
        expect(scope).not_to include(other_list)
      end

      it 'returns lists user is a member of' do
        member_list = create(:list, user: other_user)
        create(:membership, list: member_list, user: list_owner, role: "viewer")

        scope = ListPolicy::Scope.new(list_owner, List).resolve

        expect(scope).to include(member_list)
      end
    end
  end
end
