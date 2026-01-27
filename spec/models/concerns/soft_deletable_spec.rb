# frozen_string_literal: true

require "rails_helper"

RSpec.describe SoftDeletable, type: :model do
  # Use Task as the test subject since it includes SoftDeletable
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe "#soft_delete!" do
    it "sets deleted_at timestamp" do
      expect { task.soft_delete! }.to change { task.deleted_at }.from(nil)
    end

    it "excludes record from default scope" do
      task.soft_delete!
      expect(Task.all).not_to include(task)
    end
  end

  describe "#restore!" do
    before { task.soft_delete! }

    it "clears deleted_at timestamp" do
      expect { task.restore! }.to change { task.deleted_at }.to(nil)
    end

    it "includes record in default scope" do
      task.restore!
      expect(Task.all).to include(task)
    end
  end

  describe "#deleted?" do
    it "returns false for non-deleted records" do
      expect(task.deleted?).to be false
    end

    it "returns true for soft-deleted records" do
      task.soft_delete!
      expect(task.deleted?).to be true
    end
  end

  describe "scopes" do
    let!(:active_task) { create(:task, list: list, creator: user) }
    let!(:deleted_task) { create(:task, list: list, creator: user).tap(&:soft_delete!) }

    describe ".with_deleted" do
      it "includes both active and deleted records" do
        expect(Task.with_deleted).to include(active_task, deleted_task)
      end
    end

    describe ".only_deleted" do
      it "includes only deleted records" do
        expect(Task.only_deleted).to include(deleted_task)
        expect(Task.only_deleted).not_to include(active_task)
      end
    end

    describe ".not_deleted" do
      it "includes only active records" do
        expect(Task.not_deleted).to include(active_task)
        expect(Task.not_deleted).not_to include(deleted_task)
      end
    end

    describe "default_scope" do
      it "excludes deleted records by default" do
        expect(Task.all).to include(active_task)
        expect(Task.all).not_to include(deleted_task)
      end
    end
  end
end
