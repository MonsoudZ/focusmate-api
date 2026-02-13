# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringTaskInstanceJob, type: :job do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:template) { create(:task, list: list, creator: user, is_template: true, template_type: "recurring", is_recurring: true, recurrence_pattern: "daily") }
  let(:instance) { create(:task, list: list, creator: user, template: template, instance_number: 1) }

  describe "#perform" do
    it "generates next instance for a valid recurring task" do
      expect_any_instance_of(RecurringTaskService).to receive(:generate_next_instance).with(instance)

      described_class.new.perform(user_id: user.id, task_id: instance.id)
    end

    it "does nothing when user does not exist" do
      expect(RecurringTaskService).not_to receive(:new)

      described_class.new.perform(user_id: 0, task_id: instance.id)
    end

    it "does nothing when task does not exist" do
      expect(RecurringTaskService).not_to receive(:new)

      described_class.new.perform(user_id: user.id, task_id: 0)
    end

    it "does nothing when task has no template" do
      task_without_template = create(:task, list: list, creator: user)
      expect(RecurringTaskService).not_to receive(:new)

      described_class.new.perform(user_id: user.id, task_id: task_without_template.id)
    end

    it "does nothing when template is not recurring" do
      non_recurring_template = create(:task, list: list, creator: user, is_template: true, template_type: "checklist")
      task = create(:task, list: list, creator: user)
      task.update_column(:template_id, non_recurring_template.id)

      expect(RecurringTaskService).not_to receive(:new)

      described_class.new.perform(user_id: user.id, task_id: task.id)
    end
  end

  describe "queue" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
