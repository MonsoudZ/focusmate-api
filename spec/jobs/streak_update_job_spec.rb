# frozen_string_literal: true

require "rails_helper"

RSpec.describe StreakUpdateJob, type: :job do
  let(:user) { create(:user) }

  describe "#perform" do
    it "updates streak for a valid user" do
      expect_any_instance_of(StreakService).to receive(:update_streak!)

      described_class.new.perform(user_id: user.id)
    end

    it "does nothing when user does not exist" do
      expect(StreakService).not_to receive(:new)

      described_class.new.perform(user_id: 0)
    end
  end

  describe "queue" do
    it "uses the low queue" do
      expect(described_class.new.queue_name).to eq("low")
    end
  end
end
