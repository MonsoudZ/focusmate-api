# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tag, type: :model do
  let(:user) { create(:user) }
  let(:tag) { create(:tag, user: user) }

  describe "validations" do
    it "creates tag with valid attributes" do
      tag = build(:tag, name: "Work", user: user)
      expect(tag).to be_valid
    end

    it "requires name" do
      tag = build(:tag, name: nil, user: user)
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("can't be blank")
    end

    it "enforces name length limit" do
      tag = build(:tag, name: "a" * 51, user: user)
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("is too long (maximum is 50 characters)")
    end

    it "enforces name uniqueness per user (case insensitive)" do
      create(:tag, name: "Work", user: user)
      duplicate = build(:tag, name: "work", user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows same name for different users" do
      other_user = create(:user)
      create(:tag, name: "Work", user: user)
      tag = build(:tag, name: "Work", user: other_user)
      expect(tag).to be_valid
    end

    it "validates color inclusion" do
      tag = build(:tag, color: "invalid", user: user)
      expect(tag).not_to be_valid
      expect(tag.errors[:color]).to include("is not included in the list")
    end

    it "allows nil color" do
      tag = build(:tag, color: nil, user: user)
      expect(tag).to be_valid
    end

    it "allows valid colors" do
      Task::COLORS.each do |color|
        tag = build(:tag, color: color, user: user)
        expect(tag).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to user" do
      expect(tag.user).to eq(user)
    end

    it "has many task_tags" do
      list = create(:list, user: user)
      task = create(:task, list: list, creator: user)
      create(:task_tag, task: task, tag: tag)
      expect(tag.task_tags.count).to eq(1)
    end

    it "has many tasks through task_tags" do
      list = create(:list, user: user)
      task = create(:task, list: list, creator: user)
      create(:task_tag, task: task, tag: tag)
      expect(tag.tasks).to include(task)
    end

    it "destroys task_tags when destroyed" do
      list = create(:list, user: user)
      task = create(:task, list: list, creator: user)
      create(:task_tag, task: task, tag: tag)
      expect { tag.destroy }.to change(TaskTag, :count).by(-1)
    end
  end

  describe "scopes" do
    it "orders alphabetically" do
      z_tag = create(:tag, name: "Zzz", user: user)
      a_tag = create(:tag, name: "Aaa", user: user)
      expect(Tag.alphabetical).to eq([ a_tag, z_tag ])
    end
  end
end
