# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrphanedAssignmentCleanupJob, type: :job do
  let(:list_owner) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:member) { create(:user) }
  let!(:membership) { create(:membership, list: list, user: member, role: "editor") }

  describe "#perform" do
    it "unassigns tasks where user no longer has access" do
      # Create task assigned to member
      task = create(:task, list: list, creator: list_owner, assigned_to: member)

      # Remove membership (simulating the race condition aftermath)
      membership.destroy!

      # Run cleanup
      result = described_class.new.perform

      expect(result[:cleaned_up]).to eq(1)
      expect(task.reload.assigned_to_id).to be_nil
    end

    it "keeps valid assignments intact" do
      task = create(:task, list: list, creator: list_owner, assigned_to: member)

      result = described_class.new.perform

      expect(result[:cleaned_up]).to eq(0)
      expect(task.reload.assigned_to_id).to eq(member.id)
    end

    it "keeps assignments to list owner" do
      task = create(:task, list: list, creator: member, assigned_to: list_owner)
      membership.destroy!

      result = described_class.new.perform

      expect(result[:cleaned_up]).to eq(0)
      expect(task.reload.assigned_to_id).to eq(list_owner.id)
    end

    it "ignores deleted tasks" do
      task = create(:task, list: list, creator: list_owner, assigned_to: member)
      task.soft_delete!
      membership.destroy!

      result = described_class.new.perform

      expect(result[:cleaned_up]).to eq(0)
    end

    it "handles tasks with nil assigned_to" do
      create(:task, list: list, creator: list_owner, assigned_to: nil)

      result = described_class.new.perform

      expect(result[:cleaned_up]).to eq(0)
    end
  end
end
