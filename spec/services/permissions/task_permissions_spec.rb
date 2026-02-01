# frozen_string_literal: true

require "rails_helper"

RSpec.describe Permissions::TaskPermissions do
  let(:owner) { create(:user) }
  let(:editor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: owner) }
  let(:task) { create(:task, list: list, creator: owner) }

  before do
    create(:membership, list: list, user: editor_user, role: "editor")
    create(:membership, list: list, user: viewer_user, role: "viewer")
  end

  describe "#can_view?" do
    it "returns true for list owner" do
      expect(described_class.new(task, owner).can_view?).to be true
    end

    it "returns true for list editor" do
      expect(described_class.new(task, editor_user).can_view?).to be true
    end

    it "returns true for list viewer" do
      expect(described_class.new(task, viewer_user).can_view?).to be true
    end

    it "returns false for non-member" do
      expect(described_class.new(task, other_user).can_view?).to be false
    end

    context "when task is deleted" do
      before { task.soft_delete! }

      it "returns false for owner" do
        expect(described_class.new(task, owner).can_view?).to be false
      end
    end
  end

  describe "#can_edit?" do
    context "for list owner" do
      it "returns true" do
        expect(described_class.new(task, owner).can_edit?).to be true
      end
    end

    context "for task creator who is not list owner" do
      let(:task) { create(:task, list: list, creator: editor_user) }

      it "returns true" do
        expect(described_class.new(task, editor_user).can_edit?).to be true
      end
    end

    context "for list editor who is not task creator" do
      it "returns true" do
        expect(described_class.new(task, editor_user).can_edit?).to be true
      end
    end

    context "for list viewer" do
      it "returns false" do
        expect(described_class.new(task, viewer_user).can_edit?).to be false
      end
    end

    context "for non-member" do
      it "returns false" do
        expect(described_class.new(task, other_user).can_edit?).to be false
      end
    end

    context "when task is deleted" do
      before { task.soft_delete! }

      it "returns false for owner" do
        expect(described_class.new(task, owner).can_edit?).to be false
      end
    end
  end

  describe "#can_delete?" do
    it "returns same result as can_edit?" do
      expect(described_class.new(task, owner).can_delete?).to eq(
        described_class.new(task, owner).can_edit?
      )
      expect(described_class.new(task, viewer_user).can_delete?).to eq(
        described_class.new(task, viewer_user).can_edit?
      )
    end
  end

  describe "#can_nudge?" do
    it "returns true for anyone with list access" do
      expect(described_class.new(task, owner).can_nudge?).to be true
      expect(described_class.new(task, editor_user).can_nudge?).to be true
      expect(described_class.new(task, viewer_user).can_nudge?).to be true
    end

    it "returns false for non-member" do
      expect(described_class.new(task, other_user).can_nudge?).to be false
    end

    context "when task is deleted" do
      before { task.soft_delete! }

      it "returns false" do
        expect(described_class.new(task, owner).can_nudge?).to be false
      end
    end
  end

  describe "#creator?" do
    it "returns true for task creator" do
      expect(described_class.new(task, owner).creator?).to be true
    end

    it "returns false for non-creator" do
      expect(described_class.new(task, editor_user).creator?).to be false
    end
  end

  describe "#assigned?" do
    context "when task is assigned" do
      before { task.update!(assigned_to: editor_user) }

      it "returns true for assigned user" do
        expect(described_class.new(task, editor_user).assigned?).to be true
      end

      it "returns false for non-assigned user" do
        expect(described_class.new(task, owner).assigned?).to be false
      end
    end

    context "when task is not assigned" do
      it "returns false" do
        expect(described_class.new(task, owner).assigned?).to be false
      end
    end
  end

  describe "class methods" do
    it ".can_view? works correctly" do
      expect(described_class.can_view?(task, owner)).to be true
      expect(described_class.can_view?(task, other_user)).to be false
    end

    it ".can_edit? works correctly" do
      expect(described_class.can_edit?(task, owner)).to be true
      expect(described_class.can_edit?(task, viewer_user)).to be false
    end

    it ".can_delete? works correctly" do
      expect(described_class.can_delete?(task, owner)).to be true
      expect(described_class.can_delete?(task, viewer_user)).to be false
    end

    it ".can_nudge? works correctly" do
      expect(described_class.can_nudge?(task, owner)).to be true
      expect(described_class.can_nudge?(task, other_user)).to be false
    end

    it ".creator? works correctly" do
      expect(described_class.creator?(task, owner)).to be true
      expect(described_class.creator?(task, editor_user)).to be false
    end
  end

  describe "nil handling" do
    describe "#can_view?" do
      it "returns false when user is nil" do
        expect(described_class.new(task, nil).can_view?).to be false
      end

      it "returns false when task is nil" do
        expect(described_class.new(nil, owner).can_view?).to be false
      end
    end

    describe "#can_edit?" do
      it "returns false when user is nil" do
        expect(described_class.new(task, nil).can_edit?).to be false
      end

      it "returns false when task is nil" do
        expect(described_class.new(nil, owner).can_edit?).to be false
      end
    end

    describe "#can_nudge?" do
      it "returns false when user is nil" do
        expect(described_class.new(task, nil).can_nudge?).to be false
      end

      it "returns false when task is nil" do
        expect(described_class.new(nil, owner).can_nudge?).to be false
      end
    end

    describe "#creator?" do
      it "returns false when user is nil" do
        expect(described_class.new(task, nil).creator?).to be false
      end

      it "returns false when task is nil" do
        expect(described_class.new(nil, owner).creator?).to be false
      end
    end

    describe "#assigned?" do
      it "returns false when user is nil" do
        expect(described_class.new(task, nil).assigned?).to be false
      end

      it "returns false when task is nil" do
        expect(described_class.new(nil, owner).assigned?).to be false
      end
    end
  end

  describe "task with nil list" do
    it "#can_view? returns false" do
      task_without_list = build(:task, list: nil, creator: owner)
      allow(task_without_list).to receive(:list).and_return(nil)

      expect(described_class.new(task_without_list, owner).can_view?).to be false
    end

    it "#can_edit? returns false" do
      task_without_list = build(:task, list: nil, creator: owner)
      allow(task_without_list).to receive(:list).and_return(nil)

      expect(described_class.new(task_without_list, owner).can_edit?).to be false
    end
  end
end
