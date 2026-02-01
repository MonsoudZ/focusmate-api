# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskSerializer do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  describe "#as_json" do
    it "serializes basic task attributes" do
      serializer = described_class.new(task, current_user: user)
      json = serializer.as_json

      expect(json[:id]).to eq(task.id)
      expect(json[:title]).to eq(task.title)
      expect(json[:list_id]).to eq(list.id)
      expect(json[:status]).to eq("pending")
    end

    it "includes permissions" do
      serializer = described_class.new(task, current_user: user)
      json = serializer.as_json

      expect(json[:can_edit]).to be true
      expect(json[:can_delete]).to be true
    end

    it "denies permissions for unauthorized user" do
      serializer = described_class.new(task, current_user: other_user)
      json = serializer.as_json

      expect(json[:can_edit]).to be false
      expect(json[:can_delete]).to be false
    end
  end

  describe "overdue logic" do
    context "when task is overdue" do
      let(:overdue_task) { create(:task, list: list, creator: user, due_at: 30.minutes.ago, status: :pending) }

      it "returns overdue true" do
        serializer = described_class.new(overdue_task, current_user: user)
        json = serializer.as_json

        expect(json[:overdue]).to be true
      end

      it "calculates minutes_overdue" do
        serializer = described_class.new(overdue_task, current_user: user)
        json = serializer.as_json

        expect(json[:minutes_overdue]).to be >= 30
      end
    end

    context "when task is in_progress and overdue" do
      let(:in_progress_task) { create(:task, list: list, creator: user, due_at: 30.minutes.ago, status: :in_progress) }

      it "returns overdue true" do
        serializer = described_class.new(in_progress_task, current_user: user)
        json = serializer.as_json

        expect(json[:overdue]).to be true
      end
    end

    context "when task is completed" do
      let(:done_task) { create(:task, list: list, creator: user, due_at: 30.minutes.ago, status: :done) }

      it "returns overdue false" do
        serializer = described_class.new(done_task, current_user: user)
        json = serializer.as_json

        expect(json[:overdue]).to be false
        expect(json[:minutes_overdue]).to eq(0)
      end
    end

    context "when task has no due_at" do
      let(:no_due_task) { create(:task, list: list, creator: user, parent_task: task, due_at: nil) }

      it "returns overdue false" do
        serializer = described_class.new(no_due_task, current_user: user)
        json = serializer.as_json

        expect(json[:overdue]).to be false
        expect(json[:minutes_overdue]).to eq(0)
      end
    end

    context "when task has nil status" do
      it "treats nil status as overdue when past due" do
        overdue_task = create(:task, list: list, creator: user, due_at: 30.minutes.ago)
        overdue_task.update_column(:status, nil)

        serializer = described_class.new(overdue_task.reload, current_user: user)
        json = serializer.as_json

        expect(json[:overdue]).to be true
      end
    end
  end

  describe "completed_at logic" do
    context "when task is done" do
      it "uses completed_at if present" do
        completed_time = 1.hour.ago
        done_task = create(:task, list: list, creator: user, status: :done, completed_at: completed_time)

        serializer = described_class.new(done_task, current_user: user)
        json = serializer.as_json

        expect(json[:completed_at]).to eq(completed_time.iso8601)
      end

      it "falls back to updated_at if completed_at is nil" do
        done_task = create(:task, list: list, creator: user, status: :done)
        done_task.update_column(:completed_at, nil)

        serializer = described_class.new(done_task.reload, current_user: user)
        json = serializer.as_json

        expect(json[:completed_at]).to eq(done_task.updated_at.iso8601)
      end
    end

    context "when task is pending" do
      it "returns nil for completed_at" do
        serializer = described_class.new(task, current_user: user)
        json = serializer.as_json

        expect(json[:completed_at]).to be_nil
      end
    end
  end

  describe "creator_data" do
    it "includes creator information" do
      serializer = described_class.new(task, current_user: user)
      json = serializer.as_json

      expect(json[:creator][:id]).to eq(user.id)
      expect(json[:creator][:email]).to eq(user.email)
      expect(json[:creator][:name]).to eq(user.name)
    end

    it "falls back to list user if creator is nil" do
      # Reload task with association so it gets the list.user fallback
      task_without_creator = Task.find(task.id)
      task_without_creator.instance_variable_set(:@creator, nil)
      allow(task_without_creator).to receive(:creator).and_return(nil)

      serializer = described_class.new(task_without_creator, current_user: user)
      json = serializer.as_json

      expect(json[:creator][:id]).to eq(list.user.id)
    end
  end

  describe "subtasks" do
    let!(:subtask1) { create(:task, list: list, creator: user, parent_task: task, due_at: nil, position: 1) }
    let!(:subtask2) { create(:task, list: list, creator: user, parent_task: task, due_at: nil, position: 2, status: :done) }

    it "includes subtasks array for parent tasks" do
      serializer = described_class.new(task, current_user: user)
      json = serializer.as_json

      expect(json[:subtasks]).to be_an(Array)
      expect(json[:subtasks].size).to eq(2)
    end

    it "calculates subtask counts" do
      serializer = described_class.new(task, current_user: user)
      json = serializer.as_json

      expect(json[:has_subtasks]).to be true
      expect(json[:subtasks_count]).to eq(2)
      expect(json[:subtasks_completed_count]).to eq(1)
      expect(json[:subtask_completion_percentage]).to eq(50)
    end

    it "excludes subtasks array for subtask itself" do
      serializer = described_class.new(subtask1, current_user: user)
      json = serializer.as_json

      expect(json).not_to have_key(:subtasks)
    end

    it "respects include_subtasks option" do
      serializer = described_class.new(task, current_user: user, include_subtasks: false)
      json = serializer.as_json

      expect(json).not_to have_key(:subtasks)
    end

    context "when task has no subtasks" do
      let(:standalone_task) { create(:task, list: list, creator: user) }

      it "returns zero for subtask percentage" do
        serializer = described_class.new(standalone_task, current_user: user)
        json = serializer.as_json

        expect(json[:has_subtasks]).to be false
        expect(json[:subtasks_count]).to eq(0)
        expect(json[:subtask_completion_percentage]).to eq(0)
      end
    end

    context "when subtasks are preloaded" do
      it "uses preloaded subtasks" do
        task_with_preload = Task.includes(:subtasks).find(task.id)

        serializer = described_class.new(task_with_preload, current_user: user)
        json = serializer.as_json

        expect(json[:subtasks_count]).to eq(2)
      end
    end

    context "when subtask is done without completed_at" do
      it "falls back to updated_at" do
        subtask2.update_column(:completed_at, nil)
        subtask2.reload

        serializer = described_class.new(task, current_user: user)
        json = serializer.as_json
        done_subtask = json[:subtasks].find { |s| s[:id] == subtask2.id }

        expect(done_subtask[:completed_at]).to eq(subtask2.updated_at.iso8601)
      end
    end
  end

  describe "tags" do
    let!(:tag1) { create(:tag, name: "urgent", color: "red", user: user) }

    before do
      task.tags << tag1
    end

    it "serializes tags" do
      serializer = described_class.new(task, current_user: user)
      json = serializer.as_json

      expect(json[:tags]).to be_an(Array)
      expect(json[:tags].first[:name]).to eq("urgent")
      expect(json[:tags].first[:color]).to eq("red")
    end

    context "when tags are preloaded" do
      it "uses preloaded tags" do
        task_with_tags = Task.includes(:tags).find(task.id)

        serializer = described_class.new(task_with_tags, current_user: user)
        json = serializer.as_json

        expect(json[:tags].first[:name]).to eq("urgent")
      end
    end
  end

  describe "recurring task attributes" do
    let(:recurring_task) do
      create(:task,
             list: list,
             creator: user,
             is_recurring: true,
             recurrence_pattern: "daily",
             recurrence_interval: 2,
             recurrence_days: [ 1, 3, 5 ])
    end

    it "includes recurring attributes" do
      serializer = described_class.new(recurring_task, current_user: user)
      json = serializer.as_json

      expect(json[:is_recurring]).to be true
      expect(json[:recurrence_pattern]).to eq("daily")
      expect(json[:recurrence_interval]).to eq(2)
      expect(json[:recurrence_days]).to eq([ 1, 3, 5 ])
    end
  end

  describe "location-based attributes" do
    let(:location_task) do
      create(:task,
             list: list,
             creator: user,
             location_based: true,
             location_name: "Office",
             location_latitude: 40.7128,
             location_longitude: -74.0060,
             location_radius_meters: 200,
             notify_on_arrival: false,
             notify_on_departure: true)
    end

    it "includes location attributes" do
      serializer = described_class.new(location_task, current_user: user)
      json = serializer.as_json

      expect(json[:location_based]).to be true
      expect(json[:location_name]).to eq("Office")
      expect(json[:location_latitude]).to eq(40.7128)
      expect(json[:location_longitude]).to eq(-74.006)
      expect(json[:location_radius_meters]).to eq(200)
      expect(json[:notify_on_arrival]).to be false
      expect(json[:notify_on_departure]).to be true
    end

    context "with default notification settings" do
      let(:location_task_defaults) do
        create(:task,
               list: list,
               creator: user,
               location_based: true,
               notify_on_arrival: nil)
      end

      it "defaults notify_on_arrival to true" do
        serializer = described_class.new(location_task_defaults, current_user: user)
        json = serializer.as_json

        expect(json[:notify_on_arrival]).to be true
      end
    end
  end

  describe "missed reason attributes" do
    let(:overdue_task) do
      create(:task,
             list: list,
             creator: user,
             due_at: 1.hour.ago,
             requires_explanation_if_missed: true,
             missed_reason: "Was in a meeting",
             missed_reason_submitted_at: 30.minutes.ago)
    end

    it "includes missed reason fields" do
      serializer = described_class.new(overdue_task, current_user: user)
      json = serializer.as_json

      expect(json[:requires_explanation_if_missed]).to be true
      expect(json[:missed_reason]).to eq("Was in a meeting")
      expect(json[:missed_reason_submitted_at]).to be_present
    end
  end
end
