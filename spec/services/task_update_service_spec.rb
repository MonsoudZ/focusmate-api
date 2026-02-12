# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskUpdateService do
  let(:list_owner) { create(:user) }
  let(:task_creator) { create(:user) }
  let(:list_editor) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:task) { create(:task, list: list, creator: task_creator, title: "Original Title") }

  before do
    # Create editor membership
    if list.respond_to?(:memberships)
      create(:membership, list: list, user: list_editor, role: "editor")
    end
  end

  describe "#call!" do
    context "when user is the list owner" do
      it "updates the task successfully" do
        result = described_class.call!(task: task, user: list_owner, attributes: { title: "Updated Title" })

        expect(result).to eq(task)
        expect(task.reload.title).to eq("Updated Title")
      end

      it "updates multiple attributes" do
        described_class.call!(task: task, user: list_owner, attributes: {
          title: "New Title",
          note: "New Note",
          strict_mode: false
        })

        task.reload
        expect(task.title).to eq("New Title")
        expect(task.note).to eq("New Note")
        expect(task.strict_mode).to be false
      end

      it "returns the task object" do
        result = described_class.call!(task: task, user: list_owner, attributes: { title: "Test" })

        expect(result).to be_a(Task)
        expect(result).to eq(task)
      end
    end

    context "when user is the task creator" do
      it "updates the task successfully" do
        result = described_class.call!(task: task, user: task_creator, attributes: { title: "Creator Updated" })

        expect(result).to eq(task)
        expect(task.reload.title).to eq("Creator Updated")
      end
    end

    context "when user is a list editor" do
      it "updates the task successfully" do
        skip "List memberships not implemented" unless list.respond_to?(:memberships)

        result = described_class.call!(task: task, user: list_editor, attributes: { title: "Editor Updated" })

        expect(result).to eq(task)
        expect(task.reload.title).to eq("Editor Updated")
      end
    end

    context "when user is not authorized" do
      it "raises UnauthorizedError" do
        expect {
          described_class.call!(task: task, user: unauthorized_user, attributes: { title: "Unauthorized Update" })
        }.to raise_error(ApplicationError::Forbidden, "You do not have permission to edit this task")
      end

      it "does not update the task" do
        expect {
          described_class.call!(task: task, user: unauthorized_user, attributes: { title: "Unauthorized Update" })
        }.to raise_error(ApplicationError::Forbidden)

        expect(task.reload.title).to eq("Original Title")
      end
    end

    context "when validation fails" do
      it "raises ValidationError with details" do
        expect {
          described_class.call!(task: task, user: list_owner, attributes: { title: "" })
        }.to raise_error(ApplicationError::Validation) do |error|
          expect(error.message).to eq("Validation failed")
          expect(error.details).to be_a(Hash)
          expect(error.details).to have_key(:title)
        end
      end

      it "does not update the task on validation failure" do
        expect {
          described_class.call!(task: task, user: list_owner, attributes: { title: "" })
        }.to raise_error(ApplicationError::Validation)

        expect(task.reload.title).to eq("Original Title")
      end
    end

    context "when updating with due_at" do
      it "updates the due_at successfully" do
        new_due_at = 2.hours.from_now

        described_class.call!(task: task, user: list_owner, attributes: { due_at: new_due_at })

        expect(task.reload.due_at).to be_within(1.second).of(new_due_at)
      end
    end

    context "when updating with visibility" do
      it "updates the visibility successfully" do
        described_class.call!(task: task, user: list_owner, attributes: { visibility: "private_task" })

        expect(task.reload.visibility).to eq("private_task")
      end
    end

    context "when updating with strict_mode" do
      it "updates strict_mode successfully" do
        described_class.call!(task: task, user: list_owner, attributes: { strict_mode: false })

        expect(task.reload.strict_mode).to be false
      end
    end
  end

  describe "analytics tracking" do
    context "when priority changes" do
      it "tracks task_priority_changed" do
        task = create(:task, list: list, creator: list_owner, priority: :low)

        expect(AnalyticsTracker).to receive(:task_priority_changed).with(
          task, list_owner, from: "low", to: "high"
        )

        described_class.call!(task: task, user: list_owner, attributes: { priority: :high })
      end
    end

    context "when priority stays the same" do
      it "does not track task_priority_changed" do
        task = create(:task, list: list, creator: list_owner, priority: :low)

        expect(AnalyticsTracker).not_to receive(:task_priority_changed)

        described_class.call!(task: task, user: list_owner, attributes: { priority: :low })
      end
    end

    context "when task is starred" do
      it "tracks task_starred" do
        task = create(:task, list: list, creator: list_owner, starred: false)

        expect(AnalyticsTracker).to receive(:task_starred).with(task, list_owner)

        described_class.call!(task: task, user: list_owner, attributes: { starred: true })
      end
    end

    context "when task is unstarred" do
      it "tracks task_unstarred" do
        task = create(:task, list: list, creator: list_owner, starred: true)

        expect(AnalyticsTracker).to receive(:task_unstarred).with(task, list_owner)

        described_class.call!(task: task, user: list_owner, attributes: { starred: false })
      end
    end

    context "when starred stays the same" do
      it "does not track starred analytics" do
        task = create(:task, list: list, creator: list_owner, starred: true)

        expect(AnalyticsTracker).not_to receive(:task_starred)
        expect(AnalyticsTracker).not_to receive(:task_unstarred)

        described_class.call!(task: task, user: list_owner, attributes: { starred: true })
      end
    end
  end

  describe "ValidationError" do
    it "stores details hash" do
      error = ApplicationError::Validation.new("Test message", details: { field: [ "error" ] })

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({ field: [ "error" ] })
    end

    it "handles empty details" do
      error = ApplicationError::Validation.new("Test message")

      expect(error.message).to eq("Test message")
      expect(error.details).to eq({})
    end
  end
end
