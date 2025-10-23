# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemVisibilityRestriction, type: :model do
  let(:coach) { create(:user, role: "coach") }
  let(:client) { create(:user, role: "client") }
  let(:other_coach) { create(:user, role: "coach") }
  
  let(:coaching_relationship) { create(:coaching_relationship, coach: coach, client: client, invited_by: coach, status: :active) }
  let(:other_relationship) { create(:coaching_relationship, coach: other_coach, client: client, invited_by: other_coach, status: :active) }
  
  let(:list) { create(:list, owner: client) }
  let(:task) { create(:task, list: list, creator: client) }
  
  let(:restriction) { build(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship) }

  describe 'validations' do
    it 'belongs to task' do
      expect(restriction).to be_valid
      expect(restriction.task).to eq(task)
    end

    it 'belongs to coaching_relationship' do
      expect(restriction).to be_valid
      expect(restriction.coaching_relationship).to eq(coaching_relationship)
    end

    it 'requires task' do
      restriction.task = nil
      expect(restriction).not_to be_valid
      expect(restriction.errors[:task]).to include("must exist")
    end

    it 'requires coaching_relationship' do
      restriction.coaching_relationship = nil
      expect(restriction).not_to be_valid
      expect(restriction.errors[:coaching_relationship]).to include("must exist")
    end

    it 'validates unique task per coaching_relationship' do
      restriction.save!
      
      duplicate_restriction = build(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship)
      expect(duplicate_restriction).not_to be_valid
      expect(duplicate_restriction.errors[:task]).to include("has already been taken")
    end

    it 'allows same task for different coaching_relationships' do
      restriction.save!
      other_restriction = build(:item_visibility_restriction, task: task, coaching_relationship: other_relationship)
      expect(other_restriction).to be_valid
    end

    it 'allows same coaching_relationship for different tasks' do
      other_task = create(:task, list: list, creator: client)
      restriction.save!
      other_restriction = build(:item_visibility_restriction, task: other_task, coaching_relationship: coaching_relationship)
      expect(other_restriction).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to task' do
      expect(restriction.task).to eq(task)
    end

    it 'belongs to coaching_relationship' do
      expect(restriction.coaching_relationship).to eq(coaching_relationship)
    end
  end

  describe 'scopes' do
    it 'has for_task scope' do
      other_task = create(:task, list: list, creator: client)
      task_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship)
      other_restriction = create(:item_visibility_restriction, task: other_task, coaching_relationship: coaching_relationship)
      
      expect(ItemVisibilityRestriction.for_task(task)).to include(task_restriction)
      expect(ItemVisibilityRestriction.for_task(task)).not_to include(other_restriction)
    end

    it 'has for_coaching_relationship scope' do
      relationship_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship)
      other_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship)
      
      expect(ItemVisibilityRestriction.for_coaching_relationship(coaching_relationship)).to include(relationship_restriction)
      expect(ItemVisibilityRestriction.for_coaching_relationship(coaching_relationship)).not_to include(other_restriction)
    end

    it 'has active scope' do
      active_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship, active: true)
      inactive_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship, active: false)
      
      expect(ItemVisibilityRestriction.active).to include(active_restriction)
      expect(ItemVisibilityRestriction.active).not_to include(inactive_restriction)
    end

    it 'has inactive scope' do
      active_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship, active: true)
      inactive_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship, active: false)
      
      expect(ItemVisibilityRestriction.inactive).to include(inactive_restriction)
      expect(ItemVisibilityRestriction.inactive).not_to include(active_restriction)
    end
  end

  describe 'methods' do
    it 'checks if restriction is active' do
      active_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship, active: true)
      inactive_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship, active: false)
      
      expect(active_restriction.active?).to be true
      expect(inactive_restriction.active?).to be false
    end

    it 'checks if restriction is inactive' do
      active_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship, active: true)
      inactive_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship, active: false)
      
      expect(inactive_restriction.inactive?).to be true
      expect(active_restriction.inactive?).to be false
    end

    it 'activates restriction' do
      restriction.active = false
      restriction.activate!
      expect(restriction.active).to be true
    end

    it 'deactivates restriction' do
      restriction.active = true
      restriction.deactivate!
      expect(restriction.active).to be false
    end

    it 'returns restriction summary' do
      restriction.active = true
      summary = restriction.summary
      expect(summary).to include(:id, :task_id, :coaching_relationship_id, :active)
    end

    it 'returns restriction details' do
      restriction.active = true
      details = restriction.details
      expect(details).to include(:id, :task_id, :coaching_relationship_id, :active, :created_at, :updated_at)
    end

    it 'returns age in hours' do
      restriction.created_at = 2.hours.ago
      expect(restriction.age_hours).to be >= 2
    end

    it 'checks if restriction is recent' do
      restriction.created_at = 30.minutes.ago
      expect(restriction.recent?).to be true
      
      restriction.created_at = 2.hours.ago
      expect(restriction.recent?).to be false
    end

    it 'returns priority level' do
      restriction.active = true
      expect(restriction.priority).to eq("high")
      
      restriction.active = false
      expect(restriction.priority).to eq("low")
    end

    it 'returns restriction type' do
      expect(restriction.restriction_type).to eq("visibility")
    end

    it 'checks if restriction is actionable' do
      restriction.active = true
      expect(restriction.actionable?).to be true
      
      restriction.active = false
      expect(restriction.actionable?).to be false
    end

    it 'returns restriction data' do
      restriction.active = true
      data = restriction.restriction_data
      expect(data).to include(:task_id, :coaching_relationship_id, :active)
    end

    it 'generates restriction report' do
      restriction.active = true
      report = restriction.generate_report
      expect(report).to include(:restriction_type, :active, :task_id, :coaching_relationship_id)
    end
  end

  describe 'callbacks' do
    it 'sets default active status before validation' do
      restriction.active = nil
      restriction.valid?
      expect(restriction.active).to be true
    end

    it 'does not override existing active status' do
      restriction.active = false
      restriction.valid?
      expect(restriction.active).to be false
    end
  end

  describe 'soft deletion' do
    it 'soft deletes restriction' do
      restriction.save!
      restriction.soft_delete!
      expect(restriction.deleted?).to be true
      expect(restriction.deleted_at).not_to be_nil
    end

    it 'restores soft deleted restriction' do
      restriction.save!
      restriction.soft_delete!
      restriction.restore!
      expect(restriction.deleted?).to be false
      expect(restriction.deleted_at).to be_nil
    end

    it 'excludes soft deleted restrictions from default scope' do
      restriction.save!
      restriction.soft_delete!
      expect(ItemVisibilityRestriction.all).not_to include(restriction)
      expect(ItemVisibilityRestriction.with_deleted).to include(restriction)
    end
  end

  describe 'visibility management' do
    it 'creates visibility restriction' do
      restriction = ItemVisibilityRestriction.create!(
        task: task,
        coaching_relationship: coaching_relationship
      )
      expect(restriction).to be_persisted
      expect(restriction.active).to be true
    end

    it 'activates visibility restriction' do
      restriction.active = false
      restriction.activate!
      expect(restriction.active).to be true
    end

    it 'deactivates visibility restriction' do
      restriction.active = true
      restriction.deactivate!
      expect(restriction.active).to be false
    end

    it 'toggles restriction status' do
      restriction.active = true
      restriction.toggle!
      expect(restriction.active).to be false
      
      restriction.toggle!
      expect(restriction.active).to be true
    end
  end

  describe 'coaching relationship integration' do
    it 'belongs to active coaching relationship' do
      expect(restriction.coaching_relationship.status).to eq("active")
    end

    it 'cannot be created for inactive coaching relationship' do
      coaching_relationship.update!(status: :inactive)
      restriction = build(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship)
      expect(restriction).not_to be_valid
      expect(restriction.errors[:coaching_relationship]).to include("must be active")
    end

    it 'can be created for active coaching relationship' do
      expect(restriction).to be_valid
    end
  end

  describe 'task integration' do
    it 'belongs to task' do
      expect(restriction.task).to eq(task)
    end

    it 'can be created for any task' do
      other_task = create(:task, list: list, creator: client)
      other_restriction = build(:item_visibility_restriction, task: other_task, coaching_relationship: coaching_relationship)
      expect(other_restriction).to be_valid
    end
  end

  describe 'restriction management' do
    it 'manages multiple restrictions for same task' do
      restriction1 = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship)
      restriction2 = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship)
      
      expect(ItemVisibilityRestriction.for_task(task)).to include(restriction1, restriction2)
    end

    it 'manages multiple restrictions for same coaching relationship' do
      other_task = create(:task, list: list, creator: client)
      restriction1 = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship)
      restriction2 = create(:item_visibility_restriction, task: other_task, coaching_relationship: coaching_relationship)
      
      expect(ItemVisibilityRestriction.for_coaching_relationship(coaching_relationship)).to include(restriction1, restriction2)
    end

    it 'filters active restrictions' do
      active_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: coaching_relationship, active: true)
      inactive_restriction = create(:item_visibility_restriction, task: task, coaching_relationship: other_relationship, active: false)
      
      active_restrictions = ItemVisibilityRestriction.active
      expect(active_restrictions).to include(active_restriction)
      expect(active_restrictions).not_to include(inactive_restriction)
    end
  end

  describe 'restriction types' do
    it 'defines restriction type' do
      expect(restriction.restriction_type).to eq("visibility")
    end

    it 'returns restriction category' do
      expect(restriction.category).to eq("visibility")
    end

    it 'returns restriction level' do
      restriction.active = true
      expect(restriction.level).to eq("high")
      
      restriction.active = false
      expect(restriction.level).to eq("low")
    end
  end

  describe 'restriction data' do
    it 'stores restriction metadata' do
      restriction.metadata = { "reason" => "sensitive", "notes" => "Contains personal information" }
      expect(restriction).to be_valid
      expect(restriction.metadata["reason"]).to eq("sensitive")
      expect(restriction.metadata["notes"]).to eq("Contains personal information")
    end

    it 'handles empty metadata' do
      restriction.metadata = {}
      expect(restriction).to be_valid
      expect(restriction.metadata).to eq({})
    end

    it 'validates metadata structure' do
      restriction.metadata = { "invalid" => "structure" }
      expect(restriction).to be_valid
    end
  end
end
