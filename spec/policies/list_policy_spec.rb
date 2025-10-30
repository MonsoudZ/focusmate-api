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

  describe '#invite_member?' do
    it 'allows the list owner' do
      policy = described_class.new(list_owner, list)
      expect(policy.invite_member?).to be true
    end

    it 'denies access to users without invite access' do
      policy = described_class.new(other_user, list)
      expect(policy.invite_member?).to be false
    end
  end

  describe 'Scope' do
    describe '#resolve' do
      it 'returns lists accessible by the user' do
        accessible_lists = double('accessible_lists')
        allow(List).to receive(:accessible_by).with(list_owner).and_return(accessible_lists)

        scope = ListPolicy::Scope.new(list_owner, List).resolve

        expect(List).to have_received(:accessible_by).with(list_owner)
        expect(scope).to eq(accessible_lists)
      end
    end
  end
end
