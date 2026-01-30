# frozen_string_literal: true

require "rails_helper"

RSpec.describe Permissions::ListPermissions do
  let(:owner) { create(:user) }
  let(:editor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: owner) }

  before do
    create(:membership, list: list, user: editor_user, role: "editor")
    create(:membership, list: list, user: viewer_user, role: "viewer")
  end

  describe "#role" do
    it "returns 'owner' for list owner" do
      expect(described_class.new(list, owner).role).to eq("owner")
    end

    it "returns 'editor' for editor member" do
      expect(described_class.new(list, editor_user).role).to eq("editor")
    end

    it "returns 'viewer' for viewer member" do
      expect(described_class.new(list, viewer_user).role).to eq("viewer")
    end

    it "returns nil for non-member" do
      expect(described_class.new(list, other_user).role).to be_nil
    end

    it "returns nil when user is nil" do
      expect(described_class.new(list, nil).role).to be_nil
    end
  end

  describe "#owner?" do
    it "returns true for list owner" do
      expect(described_class.new(list, owner).owner?).to be true
    end

    it "returns false for editor" do
      expect(described_class.new(list, editor_user).owner?).to be false
    end

    it "returns false for viewer" do
      expect(described_class.new(list, viewer_user).owner?).to be false
    end

    it "returns false for non-member" do
      expect(described_class.new(list, other_user).owner?).to be false
    end
  end

  describe "#editor?" do
    it "returns false for owner" do
      expect(described_class.new(list, owner).editor?).to be false
    end

    it "returns true for editor member" do
      expect(described_class.new(list, editor_user).editor?).to be true
    end

    it "returns false for viewer member" do
      expect(described_class.new(list, viewer_user).editor?).to be false
    end
  end

  describe "#member?" do
    it "returns false for owner" do
      expect(described_class.new(list, owner).member?).to be false
    end

    it "returns true for editor member" do
      expect(described_class.new(list, editor_user).member?).to be true
    end

    it "returns true for viewer member" do
      expect(described_class.new(list, viewer_user).member?).to be true
    end

    it "returns false for non-member" do
      expect(described_class.new(list, other_user).member?).to be false
    end
  end

  describe "#can_view?" do
    it "returns true for owner" do
      expect(described_class.new(list, owner).can_view?).to be true
    end

    it "returns true for editor" do
      expect(described_class.new(list, editor_user).can_view?).to be true
    end

    it "returns true for viewer" do
      expect(described_class.new(list, viewer_user).can_view?).to be true
    end

    it "returns false for non-member" do
      expect(described_class.new(list, other_user).can_view?).to be false
    end

    context "when list is deleted" do
      before { list.soft_delete! }

      it "returns false for owner" do
        expect(described_class.new(list, owner).can_view?).to be false
      end
    end
  end

  describe "#can_edit?" do
    it "returns true for owner" do
      expect(described_class.new(list, owner).can_edit?).to be true
    end

    it "returns true for editor" do
      expect(described_class.new(list, editor_user).can_edit?).to be true
    end

    it "returns false for viewer" do
      expect(described_class.new(list, viewer_user).can_edit?).to be false
    end

    it "returns false for non-member" do
      expect(described_class.new(list, other_user).can_edit?).to be false
    end

    context "when list is deleted" do
      before { list.soft_delete! }

      it "returns false for owner" do
        expect(described_class.new(list, owner).can_edit?).to be false
      end
    end
  end

  describe "#can_delete?" do
    it "returns true for owner" do
      expect(described_class.new(list, owner).can_delete?).to be true
    end

    it "returns false for editor" do
      expect(described_class.new(list, editor_user).can_delete?).to be false
    end

    it "returns false for viewer" do
      expect(described_class.new(list, viewer_user).can_delete?).to be false
    end
  end

  describe "#can_manage_memberships?" do
    it "returns true for owner" do
      expect(described_class.new(list, owner).can_manage_memberships?).to be true
    end

    it "returns false for editor" do
      expect(described_class.new(list, editor_user).can_manage_memberships?).to be false
    end

    it "returns false for viewer" do
      expect(described_class.new(list, viewer_user).can_manage_memberships?).to be false
    end
  end

  describe "class methods" do
    it ".role_for returns correct role" do
      expect(described_class.role_for(list, owner)).to eq("owner")
    end

    it ".can_edit? works correctly" do
      expect(described_class.can_edit?(list, owner)).to be true
      expect(described_class.can_edit?(list, viewer_user)).to be false
    end

    it ".can_view? works correctly" do
      expect(described_class.can_view?(list, owner)).to be true
      expect(described_class.can_view?(list, other_user)).to be false
    end

    it ".accessible? works correctly" do
      expect(described_class.accessible?(list, owner)).to be true
      expect(described_class.accessible?(list, other_user)).to be false
    end

    it ".can_delete? works correctly" do
      expect(described_class.can_delete?(list, owner)).to be true
      expect(described_class.can_delete?(list, editor_user)).to be false
    end
  end

  describe "nil user handling" do
    it "#can_view? returns false when user is nil" do
      expect(described_class.new(list, nil).can_view?).to be false
    end

    it "#can_edit? returns false when user is nil" do
      expect(described_class.new(list, nil).can_edit?).to be false
    end

    it "#can_delete? returns false when user is nil" do
      expect(described_class.new(list, nil).can_delete?).to be false
    end
  end

  describe "nil list handling" do
    it "#can_view? returns false when list is nil" do
      expect(described_class.new(nil, owner).can_view?).to be false
    end

    it "#can_edit? returns false when list is nil" do
      expect(described_class.new(nil, owner).can_edit?).to be false
    end

    it "#role returns nil when list is nil" do
      expect(described_class.new(nil, owner).role).to be_nil
    end
  end

  describe "#viewer?" do
    it "returns true for viewer member" do
      expect(described_class.new(list, viewer_user).viewer?).to be true
    end

    it "returns false for owner" do
      expect(described_class.new(list, owner).viewer?).to be false
    end

    it "returns false for editor" do
      expect(described_class.new(list, editor_user).viewer?).to be false
    end
  end
end
