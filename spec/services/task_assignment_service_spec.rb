# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskAssignmentService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:service) { described_class.new(task: task, user: user) }

  describe "#assign!" do
    it "assigns a user who has access to the list" do
      assignee = create(:user)
      create(:membership, list: list, user: assignee, role: "editor")

      service.assign!(assigned_to_id: assignee.id)

      expect(task.reload.assigned_to_id).to eq(assignee.id)
    end

    it "allows assigning the list owner" do
      service.assign!(assigned_to_id: user.id)

      expect(task.reload.assigned_to_id).to eq(user.id)
    end

    it "raises BadRequest when assigned_to_id is blank" do
      expect {
        service.assign!(assigned_to_id: nil)
      }.to raise_error(TaskAssignmentService::BadRequest, "assigned_to is required")
    end

    it "raises InvalidAssignee when user does not exist" do
      expect {
        service.assign!(assigned_to_id: 99999)
      }.to raise_error(TaskAssignmentService::InvalidAssignee, "User cannot be assigned to this task")
    end

    it "raises InvalidAssignee when user has no access to the list" do
      stranger = create(:user)

      expect {
        service.assign!(assigned_to_id: stranger.id)
      }.to raise_error(TaskAssignmentService::InvalidAssignee, "User cannot be assigned to this task")
    end

    it "returns the task" do
      result = service.assign!(assigned_to_id: user.id)
      expect(result).to eq(task)
    end
  end

  describe "#unassign!" do
    it "clears the assignment" do
      task.update!(assigned_to_id: user.id)

      service.unassign!

      expect(task.reload.assigned_to_id).to be_nil
    end

    it "returns the task" do
      result = service.unassign!
      expect(result).to eq(task)
    end
  end
end
