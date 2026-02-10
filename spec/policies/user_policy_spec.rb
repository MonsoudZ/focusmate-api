# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "show?" do
    it "allows viewing own profile" do
      policy = described_class.new(user, user)
      expect(policy.show?).to be true
    end

    it "blocks viewing other profiles" do
      policy = described_class.new(user, other_user)
      expect(policy.show?).to be false
    end
  end

  describe "update?" do
    it "allows updating own profile" do
      policy = described_class.new(user, user)
      expect(policy.update?).to be true
    end

    it "blocks updating other profiles" do
      policy = described_class.new(user, other_user)
      expect(policy.update?).to be false
    end
  end

  describe "destroy?" do
    it "allows deleting own account" do
      policy = described_class.new(user, user)
      expect(policy.destroy?).to be true
    end

    it "blocks deleting other accounts" do
      policy = described_class.new(user, other_user)
      expect(policy.destroy?).to be false
    end
  end
end
