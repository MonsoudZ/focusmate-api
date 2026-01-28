# frozen_string_literal: true

require "rails_helper"

RSpec.describe Nudge, type: :model do
  let(:owner) { create(:user) }
  let(:list) { create(:list, user: owner) }
  let(:task) { create(:task, list: list, creator: owner) }
  let(:other_user) { create(:user) }

  describe "validations" do
    it "is valid with all required attributes" do
      nudge = build(:nudge, task: task, from_user: other_user, to_user: owner)
      expect(nudge).to be_valid
    end

    it "requires a task" do
      nudge = build(:nudge, task: nil, from_user: other_user, to_user: owner)
      expect(nudge).not_to be_valid
      expect(nudge.errors[:task]).to include("must exist")
    end

    it "requires a from_user" do
      nudge = build(:nudge, task: task, from_user: nil, to_user: owner)
      expect(nudge).not_to be_valid
      expect(nudge.errors[:from_user]).to include("must exist")
    end

    it "requires a to_user" do
      nudge = build(:nudge, task: task, from_user: other_user, to_user: nil)
      expect(nudge).not_to be_valid
      expect(nudge.errors[:to_user]).to include("must exist")
    end
  end

  describe "rate limiting" do
    it "allows up to 3 nudges per task per user per hour" do
      3.times do
        create(:nudge, task: task, from_user: other_user, to_user: owner)
      end

      fourth = build(:nudge, task: task, from_user: other_user, to_user: owner)
      expect(fourth).not_to be_valid
      expect(fourth.errors[:base]).to include("You can only nudge about this task 3 times per hour")
    end

    it "allows nudges after the rate limit window expires" do
      3.times do
        create(:nudge, task: task, from_user: other_user, to_user: owner,
               created_at: 2.hours.ago)
      end

      new_nudge = build(:nudge, task: task, from_user: other_user, to_user: owner)
      expect(new_nudge).to be_valid
    end

    it "rate limits per user independently" do
      another_user = create(:user)

      3.times do
        create(:nudge, task: task, from_user: other_user, to_user: owner)
      end

      nudge_from_another = build(:nudge, task: task, from_user: another_user, to_user: owner)
      expect(nudge_from_another).to be_valid
    end

    it "rate limits per task independently" do
      other_task = create(:task, list: list, creator: owner)

      3.times do
        create(:nudge, task: task, from_user: other_user, to_user: owner)
      end

      nudge_other_task = build(:nudge, task: other_task, from_user: other_user, to_user: owner)
      expect(nudge_other_task).to be_valid
    end
  end

  describe "scopes" do
    it "returns recent nudges within 24 hours" do
      recent = create(:nudge, task: task, from_user: other_user, to_user: owner)
      old = create(:nudge, task: task, from_user: other_user, to_user: owner,
                   created_at: 2.days.ago)

      expect(Nudge.recent).to include(recent)
      expect(Nudge.recent).not_to include(old)
    end
  end

  describe "associations" do
    it "belongs to a task" do
      nudge = create(:nudge, task: task, from_user: other_user, to_user: owner)
      expect(nudge.task).to eq(task)
    end

    it "belongs to from_user" do
      nudge = create(:nudge, task: task, from_user: other_user, to_user: owner)
      expect(nudge.from_user).to eq(other_user)
    end

    it "belongs to to_user" do
      nudge = create(:nudge, task: task, from_user: other_user, to_user: owner)
      expect(nudge.to_user).to eq(owner)
    end
  end
end
