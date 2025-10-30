require 'rails_helper'

RSpec.describe Membership, type: :model do
  let(:user) { create(:user) }
  let(:list) { create(:list) }
  let(:coach) { create(:user) }
  let(:client) { create(:user) }
  let(:coaching_relationship) { create(:coaching_relationship, coach: coach, client: client, status: :active) }

  describe 'associations' do
    it { should belong_to(:list) }
    it { should belong_to(:user) }
    it { should belong_to(:coaching_relationship).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:role) }
    it { should validate_inclusion_of(:role).in_array(%w[editor viewer]) }

    describe 'uniqueness validation' do
      it 'validates uniqueness of user_id scoped to list_id' do
        create(:membership, list: list, user: user, role: 'editor')
        duplicate = build(:membership, list: list, user: user, role: 'viewer')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include("is already a member of this list")
      end

      it 'allows same user in different lists' do
        other_list = create(:list)
        create(:membership, list: list, user: user, role: 'editor')
        other_membership = build(:membership, list: other_list, user: user, role: 'viewer')

        expect(other_membership).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:editor_membership) { create(:membership, list: list, user: user, role: 'editor') }
    let!(:viewer_membership) { create(:membership, list: list, user: create(:user), role: 'viewer') }

    describe '.editors' do
      it 'returns only editor memberships' do
        expect(Membership.editors).to include(editor_membership)
        expect(Membership.editors).not_to include(viewer_membership)
      end
    end

    describe '.viewers' do
      it 'returns only viewer memberships' do
        expect(Membership.viewers).to include(viewer_membership)
        expect(Membership.viewers).not_to include(editor_membership)
      end
    end
  end

  describe '#can_edit?' do
    it 'returns true for editor role' do
      membership = build(:membership, role: 'editor')
      expect(membership.can_edit?).to be true
    end

    it 'returns false for viewer role' do
      membership = build(:membership, role: 'viewer')
      expect(membership.can_edit?).to be false
    end
  end

  describe '#can_invite?' do
    it 'returns true for editor role' do
      membership = build(:membership, role: 'editor')
      expect(membership.can_invite?).to be true
    end

    it 'returns false for viewer role' do
      membership = build(:membership, role: 'viewer')
      expect(membership.can_invite?).to be false
    end
  end

  describe '#coach_membership?' do
    it 'returns true when coaching_relationship_id is present' do
      membership = create(:membership, list: list, user: coach, role: 'editor', coaching_relationship: coaching_relationship)
      expect(membership.coach_membership?).to be true
    end

    it 'returns false when coaching_relationship_id is nil' do
      membership = create(:membership, list: list, user: user, role: 'editor')
      expect(membership.coach_membership?).to be false
    end
  end

  describe '#receives_overdue_alerts?' do
    it 'returns true when receive_overdue_alerts is true' do
      membership = build(:membership, receive_overdue_alerts: true)
      expect(membership.receives_overdue_alerts?).to be true
    end

    it 'returns false when receive_overdue_alerts is false' do
      membership = build(:membership, receive_overdue_alerts: false)
      expect(membership.receives_overdue_alerts?).to be false
    end
  end

  describe '#can_add_items?' do
    it 'returns the value of can_add_items attribute' do
      membership = build(:membership, can_add_items: true)
      expect(membership.can_add_items?).to be true

      membership.can_add_items = false
      expect(membership.can_add_items?).to be false
    end
  end
end
