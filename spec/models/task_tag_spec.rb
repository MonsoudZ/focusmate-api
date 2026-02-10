# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskTag do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:tag) { create(:tag, user: user) }

  describe "associations" do
    it "belongs to task" do
      task_tag = create(:task_tag, task: task, tag: tag)
      expect(task_tag.task).to eq(task)
    end

    it "belongs to tag" do
      task_tag = create(:task_tag, task: task, tag: tag)
      expect(task_tag.tag).to eq(tag)
    end
  end

  describe "validations" do
    it "enforces uniqueness of tag per task" do
      create(:task_tag, task: task, tag: tag)
      duplicate = build(:task_tag, task: task, tag: tag)
      expect(duplicate).not_to be_valid
    end

    it "allows same tag on different tasks" do
      other_task = create(:task, list: list, creator: user)
      create(:task_tag, task: task, tag: tag)
      other_task_tag = build(:task_tag, task: other_task, tag: tag)
      expect(other_task_tag).to be_valid
    end
  end

  describe "counter cache" do
    it "increments tasks_count on tag when created" do
      expect {
        create(:task_tag, task: task, tag: tag)
      }.to change { tag.reload.tasks_count }.by(1)
    end

    it "decrements tasks_count on tag when destroyed" do
      task_tag = create(:task_tag, task: task, tag: tag)
      expect {
        task_tag.destroy!
      }.to change { tag.reload.tasks_count }.by(-1)
    end
  end
end
