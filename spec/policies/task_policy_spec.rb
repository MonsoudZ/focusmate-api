# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskPolicy, type: :policy do
  let(:owner) { create(:user) }
  let(:list)  { create(:list, user: owner) }
  let(:task)  { create(:task, list: list, creator: owner) }

  let(:other_user) { create(:user) }

  describe "owner permissions" do
    subject { described_class.new(owner, task) }

    it { expect(subject.show?).to be true }
    it { expect(subject.create?).to be true }
    it { expect(subject.update?).to be true }
    it { expect(subject.destroy?).to be true }
  end

  describe "shared list permissions" do
    let(:viewer) { create(:user) }
    let(:visible_task) { create(:task, list: list, creator: owner, visibility: "visible_to_all") }

    before do
      create(:membership, list: list, user: viewer, role: "viewer")
    end

    subject { described_class.new(viewer, visible_task) }

    it "allows viewing public tasks" do
      expect(subject.show?).to be true
    end

    it "blocks mutations" do
      expect(subject.update?).to be false
      expect(subject.destroy?).to be false
    end
  end

  describe "private visibility" do
    before { task.update!(visibility: :private_task) }

    it "blocks other users" do
      policy = described_class.new(other_user, task)
      expect(policy.show?).to be false
    end

    it "allows creator" do
      policy = described_class.new(owner, task)
      expect(policy.show?).to be true
    end

    context "when task creator is a list member (not owner)" do
      let(:member) { create(:user) }
      let(:member_task) { create(:task, list: list, creator: member, visibility: :private_task) }

      before do
        create(:membership, list: list, user: member, role: "editor")
      end

      it "allows creator to view" do
        policy = described_class.new(member, member_task)
        expect(policy.show?).to be true
      end

      it "blocks list owner from viewing" do
        policy = described_class.new(owner, member_task)
        expect(policy.show?).to be false
      end
    end
  end

  describe "Scope" do
    let(:member) { create(:user) }
    let!(:visible_task) { create(:task, list: list, creator: owner, visibility: :visible_to_all) }
    let!(:hidden_owner_task) { create(:task, list: list, creator: owner, visibility: :private_task) }
    let!(:hidden_member_task) { create(:task, list: list, creator: member, visibility: :private_task) }

    before do
      create(:membership, list: list, user: member, role: "editor")
    end

    it "includes visible tasks for all members" do
      scope = described_class::Scope.new(member, Task).resolve
      expect(scope).to include(visible_task)
    end

    it "excludes hidden tasks created by others" do
      scope = described_class::Scope.new(member, Task).resolve
      expect(scope).not_to include(hidden_owner_task)
    end

    it "includes hidden tasks created by self" do
      scope = described_class::Scope.new(member, Task).resolve
      expect(scope).to include(hidden_member_task)
    end

    it "includes own hidden tasks for creator" do
      scope = described_class::Scope.new(owner, Task).resolve
      expect(scope).to include(hidden_owner_task)
    end
  end

  describe "deleted lists" do
    before do
      list.soft_delete!
      task.reload
    end

    it "blocks access entirely" do
      policy = described_class.new(owner, task)
      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end
  end

  describe "nudge permissions" do
    let(:member) { create(:user) }
    let(:viewer) { create(:user) }

    before do
      create(:membership, list: list, user: member, role: "editor")
      create(:membership, list: list, user: viewer, role: "viewer")
    end

    it "allows list members to nudge" do
      policy = described_class.new(member, task)
      expect(policy.nudge?).to be true
    end

    it "allows viewers to nudge" do
      policy = described_class.new(viewer, task)
      expect(policy.nudge?).to be true
    end

    it "allows owner to nudge" do
      policy = described_class.new(owner, task)
      expect(policy.nudge?).to be true
    end

    it "blocks non-members from nudging" do
      policy = described_class.new(other_user, task)
      expect(policy.nudge?).to be false
    end

    it "blocks nudging deleted tasks" do
      task.soft_delete!
      policy = described_class.new(member, task)
      expect(policy.nudge?).to be false
    end
  end
end
