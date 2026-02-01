# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListSerializer do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe "#as_json" do
    it "serializes basic list attributes" do
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json[:id]).to eq(list.id)
      expect(json[:name]).to eq(list.name)
      expect(json[:visibility]).to eq(list.visibility)
    end

    it "includes default color when color is nil" do
      list.update!(color: nil)
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json[:color]).to eq("blue")
    end

    it "includes the list color when set" do
      list.update!(color: "green")
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json[:color]).to eq("green")
    end
  end

  describe "role_for_current_user" do
    it "returns owner for list owner" do
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json[:role]).to eq("owner")
    end

    it "returns editor for editor member" do
      create(:membership, list: list, user: other_user, role: "editor")
      serializer = described_class.new(list, current_user: other_user)
      json = serializer.as_json

      expect(json[:role]).to eq("editor")
    end

    it "returns viewer for viewer member" do
      create(:membership, list: list, user: other_user, role: "viewer")
      serializer = described_class.new(list, current_user: other_user)
      json = serializer.as_json

      expect(json[:role]).to eq("viewer")
    end

    it "returns nil for non-member" do
      serializer = described_class.new(list, current_user: other_user)
      json = serializer.as_json

      expect(json[:role]).to be_nil
    end

    context "with preloaded memberships" do
      it "uses preloaded memberships" do
        create(:membership, list: list, user: other_user, role: "editor")
        list_with_memberships = List.includes(:memberships).find(list.id)

        serializer = described_class.new(list_with_memberships, current_user: other_user)
        json = serializer.as_json

        expect(json[:role]).to eq("editor")
      end
    end
  end

  describe "task counts" do
    let!(:pending_task) { create(:task, list: list, creator: user, status: :pending) }
    let!(:done_task) { create(:task, list: list, creator: user, status: :done) }
    let!(:overdue_task) { create(:task, list: list, creator: user, status: :pending, due_at: 1.hour.ago) }

    it "calculates completed_tasks_count" do
      serializer = described_class.new(list.reload, current_user: user)
      json = serializer.as_json

      expect(json[:completed_tasks_count]).to eq(1)
    end

    it "calculates overdue_tasks_count" do
      serializer = described_class.new(list.reload, current_user: user)
      json = serializer.as_json

      expect(json[:overdue_tasks_count]).to eq(1)
    end

    context "with preloaded tasks" do
      it "uses preloaded tasks for completed count" do
        list_with_tasks = List.includes(:tasks).find(list.id)

        serializer = described_class.new(list_with_tasks, current_user: user)
        json = serializer.as_json

        expect(json[:completed_tasks_count]).to eq(1)
      end

      it "uses preloaded tasks for overdue count" do
        list_with_tasks = List.includes(:tasks).find(list.id)

        serializer = described_class.new(list_with_tasks, current_user: user)
        json = serializer.as_json

        expect(json[:overdue_tasks_count]).to eq(1)
      end
    end
  end

  describe "serialize_members" do
    let!(:editor_member) { create(:user, name: "Editor User") }
    let!(:viewer_member) { create(:user, name: "Viewer User") }

    before do
      create(:membership, list: list, user: editor_member, role: "editor")
      create(:membership, list: list, user: viewer_member, role: "viewer")
    end

    it "includes owner first" do
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json[:members].first[:role]).to eq("owner")
      expect(json[:members].first[:id]).to eq(user.id)
    end

    it "includes all members" do
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json[:members].size).to eq(3) # owner + 2 members
    end

    context "with preloaded memberships" do
      it "uses preloaded memberships" do
        list_with_memberships = List.includes(memberships: :user).find(list.id)

        serializer = described_class.new(list_with_memberships, current_user: user)
        json = serializer.as_json

        expect(json[:members].size).to eq(3)
      end
    end
  end

  describe "include_tasks option" do
    let!(:task) { create(:task, list: list, creator: user) }

    it "does not include tasks by default" do
      serializer = described_class.new(list, current_user: user)
      json = serializer.as_json

      expect(json).not_to have_key(:tasks)
    end

    it "includes tasks when option is true" do
      serializer = described_class.new(list, current_user: user, include_tasks: true)
      json = serializer.as_json

      expect(json).to have_key(:tasks)
      expect(json[:tasks]).to be_an(Array)
    end
  end
end
