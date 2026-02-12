# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskSerializer do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }

  def serialize(task, current_user: user, **options)
    described_class.new(task, current_user: current_user, **options).as_json
  end

  describe "#as_json" do
    it "serializes basic task attributes" do
      json = serialize(task)

      expect(json[:id]).to eq(task.id)
      expect(json[:title]).to eq(task.title)
      expect(json[:list_id]).to eq(list.id)
      expect(json[:status]).to eq("pending")
    end

    it "includes permissions" do
      json = serialize(task)

      expect(json[:can_edit]).to be true
      expect(json[:can_delete]).to be true
    end

    it "denies permissions for unauthorized user" do
      json = serialize(task, current_user: other_user)

      expect(json[:can_edit]).to be false
      expect(json[:can_delete]).to be false
    end

    it "includes hidden field as false for visible tasks" do
      json = serialize(task)

      expect(json[:hidden]).to be false
    end

    it "includes hidden field as true for private tasks" do
      hidden_task = create(:task, list: list, creator: user, visibility: :private_task)
      json = serialize(hidden_task)

      expect(json[:hidden]).to be true
    end
  end

  describe "overdue logic" do
    context "when task is overdue" do
      let(:overdue_task) { create(:task, list: list, creator: user, due_at: 30.minutes.ago, status: :pending) }

      it "returns overdue true" do
        json = serialize(overdue_task)

        expect(json[:overdue]).to be true
      end

      it "calculates minutes_overdue" do
        json = serialize(overdue_task)

        expect(json[:minutes_overdue]).to be >= 30
      end
    end

    context "when task is in_progress and overdue" do
      let(:in_progress_task) { create(:task, list: list, creator: user, due_at: 30.minutes.ago, status: :in_progress) }

      it "returns overdue true" do
        json = serialize(in_progress_task)

        expect(json[:overdue]).to be true
      end
    end

    context "when task is completed" do
      let(:done_task) { create(:task, list: list, creator: user, due_at: 30.minutes.ago, status: :done) }

      it "returns overdue false" do
        json = serialize(done_task)

        expect(json[:overdue]).to be false
        expect(json[:minutes_overdue]).to eq(0)
      end
    end

    context "when task has no due_at" do
      let(:no_due_task) { create(:task, list: list, creator: user, parent_task: task, due_at: nil) }

      it "returns overdue false" do
        json = serialize(no_due_task)

        expect(json[:overdue]).to be false
        expect(json[:minutes_overdue]).to eq(0)
      end
    end

    context "when task has nil status" do
      it "treats nil status as overdue when past due" do
        overdue_task = create(:task, list: list, creator: user, due_at: 30.minutes.ago)
        overdue_task.update_column(:status, nil)

        json = serialize(overdue_task.reload)

        expect(json[:overdue]).to be true
      end
    end
  end

  describe "completed_at logic" do
    context "when task is done" do
      it "uses completed_at if present" do
        completed_time = 1.hour.ago
        done_task = create(:task, list: list, creator: user, status: :done, completed_at: completed_time)

        json = serialize(done_task)

        expect(json[:completed_at]).to eq(completed_time.iso8601)
      end

      it "falls back to updated_at if completed_at is nil" do
        done_task = create(:task, list: list, creator: user, status: :done)
        done_task.update_column(:completed_at, nil)

        json = serialize(done_task.reload)

        expect(json[:completed_at]).to eq(done_task.updated_at.iso8601)
      end
    end

    context "when task is pending" do
      it "returns nil for completed_at" do
        json = serialize(task)

        expect(json[:completed_at]).to be_nil
      end
    end
  end

  describe "creator_data" do
    it "includes creator information" do
      json = serialize(task)

      expect(json[:creator][:id]).to eq(user.id)
      expect(json[:creator][:email]).to eq(user.email)
      expect(json[:creator][:name]).to eq(user.name)
    end

    it "falls back to list user if creator is nil" do
      # Reload task with association so it gets the list.user fallback
      task_without_creator = Task.find(task.id)
      task_without_creator.instance_variable_set(:@creator, nil)
      allow(task_without_creator).to receive(:creator).and_return(nil)

      json = serialize(task_without_creator)

      expect(json[:creator][:id]).to eq(list.user.id)
    end
  end

  describe "subtasks" do
    let!(:subtask1) { create(:task, list: list, creator: user, parent_task: task, due_at: nil, position: 1) }
    let!(:subtask2) { create(:task, list: list, creator: user, parent_task: task, due_at: nil, position: 2, status: :done) }

    it "includes subtasks array for parent tasks" do
      json = serialize(task)

      expect(json[:subtasks]).to be_an(Array)
      expect(json[:subtasks].size).to eq(2)
    end

    it "calculates subtask counts" do
      json = serialize(task)

      expect(json[:has_subtasks]).to be true
      expect(json[:subtasks_count]).to eq(2)
      expect(json[:subtasks_completed_count]).to eq(1)
      expect(json[:subtask_completion_percentage]).to eq(50)
    end

    it "excludes subtasks array for subtask itself" do
      json = serialize(subtask1)

      expect(json).not_to have_key(:subtasks)
    end

    it "respects include_subtasks option" do
      json = serialize(task, include_subtasks: false)

      expect(json).not_to have_key(:subtasks)
    end

    context "when task has no subtasks" do
      let(:standalone_task) { create(:task, list: list, creator: user) }

      it "returns zero for subtask percentage" do
        json = serialize(standalone_task)

        expect(json[:has_subtasks]).to be false
        expect(json[:subtasks_count]).to eq(0)
        expect(json[:subtask_completion_percentage]).to eq(0)
      end
    end

    context "when subtasks are preloaded" do
      it "uses preloaded subtasks" do
        task_with_preload = Task.includes(:subtasks).find(task.id)

        json = serialize(task_with_preload)

        expect(json[:subtasks_count]).to eq(2)
      end
    end

    context "when subtask is done without completed_at" do
      it "falls back to updated_at" do
        subtask2.update_column(:completed_at, nil)
        subtask2.reload

        json = serialize(task)
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
      json = serialize(task)

      expect(json[:tags]).to be_an(Array)
      expect(json[:tags].first[:name]).to eq("urgent")
      expect(json[:tags].first[:color]).to eq("red")
    end

    context "when tags are preloaded" do
      it "uses preloaded tags" do
        task_with_tags = Task.includes(:tags).find(task.id)

        json = serialize(task_with_tags)

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
      json = serialize(recurring_task)

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
      json = serialize(location_task)

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
        json = serialize(location_task_defaults)

        expect(json[:notify_on_arrival]).to be true
      end
    end
  end

  describe "reschedule_events" do
    it "includes empty array when no reschedule events" do
      json = serialize(task)

      expect(json[:reschedule_events]).to eq([])
    end

    it "includes reschedule events in reverse chronological order" do
      older_event = create(:reschedule_event, task: task, reason: "first", created_at: 2.hours.ago)
      newer_event = create(:reschedule_event, task: task, reason: "second", created_at: 1.hour.ago)

      json = serialize(task.reload)

      expect(json[:reschedule_events].length).to eq(2)
      expect(json[:reschedule_events][0][:id]).to eq(newer_event.id)
      expect(json[:reschedule_events][1][:id]).to eq(older_event.id)
    end

    it "includes all event fields" do
      event = create(:reschedule_event,
                     task: task,
                     previous_due_at: 1.day.ago,
                     new_due_at: 2.days.from_now,
                     reason: "blocked",
                     user: user)

      json = serialize(task.reload)

      event_json = json[:reschedule_events][0]
      expect(event_json[:id]).to eq(event.id)
      expect(event_json[:task_id]).to eq(task.id)
      expect(event_json[:previous_due_at]).to be_present
      expect(event_json[:new_due_at]).to be_present
      expect(event_json[:reason]).to eq("blocked")
      expect(event_json[:rescheduled_by][:id]).to eq(user.id)
      expect(event_json[:rescheduled_by][:name]).to eq(user.name)
      expect(event_json[:created_at]).to be_present
    end

    it "handles nil user gracefully" do
      event = create(:reschedule_event, task: task, user: nil)

      json = serialize(task.reload)

      expect(json[:reschedule_events][0][:rescheduled_by]).to be_nil
    end

    it "excludes reschedule_events when include_reschedule_events is false" do
      create(:reschedule_event, task: task)

      json = serialize(task.reload, include_reschedule_events: false)

      expect(json).not_to have_key(:reschedule_events)
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
      json = serialize(overdue_task)

      expect(json[:requires_explanation_if_missed]).to be true
      expect(json[:missed_reason]).to eq("Was in a meeting")
      expect(json[:missed_reason_submitted_at]).to be_present
    end
  end
end
