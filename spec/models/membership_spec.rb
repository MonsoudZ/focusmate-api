# frozen_string_literal: true

RSpec.describe Membership do
  let(:user) { create(:user) }
  let(:list_owner) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:membership) { create(:membership, list: list, user: user, role: 'editor') }

  describe 'validations' do
    it 'requires role' do
      membership = build(:membership, list: list, user: user, role: nil)
      expect(membership).not_to be_valid
    end

    it 'requires valid role' do
      membership = build(:membership, list: list, user: user, role: 'admin')
      expect(membership).not_to be_valid
    end

    it 'validates uniqueness of user per list' do
      create(:membership, list: list, user: user)
      duplicate = build(:membership, list: list, user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to list' do
      expect(membership.list).to eq(list)
    end

    it 'belongs to user' do
      expect(membership.user).to eq(user)
    end
  end

  describe 'scopes' do
    it 'has editors scope' do
      editor = create(:membership, list: list, user: create(:user), role: 'editor')
      viewer = create(:membership, list: list, user: create(:user), role: 'viewer')
      expect(Membership.editors).to include(editor)
      expect(Membership.editors).not_to include(viewer)
    end

    it 'has viewers scope' do
      editor = create(:membership, list: list, user: create(:user), role: 'editor')
      viewer = create(:membership, list: list, user: create(:user), role: 'viewer')
      expect(Membership.viewers).to include(viewer)
      expect(Membership.viewers).not_to include(editor)
    end
  end

  describe '#can_edit?' do
    it 'returns true for editor' do
      membership = build(:membership, role: 'editor')
      expect(membership.can_edit?).to be true
    end

    it 'returns false for viewer' do
      membership = build(:membership, role: 'viewer')
      expect(membership.can_edit?).to be false
    end
  end
end
