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
    it { expect(subject.complete?).to be true }
    it { expect(subject.reassign?).to be true }
    it { expect(subject.destroy?).to be true }
    it { expect(subject.change_visibility?).to be true }
  end

  describe "shared list permissions" do
    let(:viewer) { create(:user) }

    before do
      list.share_with!(viewer, can_view: true)
    end

    subject { described_class.new(viewer, task) }

    it "allows viewing" do
      expect(subject.show?).to be true
    end

    it "blocks mutations" do
      expect(subject.update?).to be false
      expect(subject.complete?).to be false
      expect(subject.reassign?).to be false
      expect(subject.destroy?).to be false
    end
  end

  describe "private visibility" do
    before { task.update!(visibility: :private_task) }

    it "blocks other users" do
      policy = described_class.new(other_user, task)
      expect(policy.show?).to be false
    end

    it "allows owner" do
      policy = described_class.new(owner, task)
      expect(policy.show?).to be true
    end
  end


  describe "deleted lists" do
    before { list.soft_delete! }

    it "blocks access entirely" do
      policy = described_class.new(owner, task)
      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end
  end
end
