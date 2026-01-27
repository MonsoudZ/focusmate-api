# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:tag) { create(:tag, user: user) }
  let(:other_tag) { create(:tag, user: other_user) }

  describe "Scope" do
    let!(:user_tag1) { create(:tag, user: user, name: "Work") }
    let!(:user_tag2) { create(:tag, user: user, name: "Personal") }
    let!(:other_tag) { create(:tag, user: other_user, name: "Other") }

    it "returns only the user's tags" do
      scope = described_class::Scope.new(user, Tag.all).resolve
      expect(scope).to include(user_tag1, user_tag2)
      expect(scope).not_to include(other_tag)
    end
  end

  describe "#show?" do
    it "allows owner to view" do
      policy = described_class.new(user, tag)
      expect(policy.show?).to be true
    end

    it "denies other users from viewing" do
      policy = described_class.new(other_user, tag)
      expect(policy.show?).to be false
    end
  end

  describe "#create?" do
    it "allows any authenticated user to create" do
      policy = described_class.new(user, Tag.new)
      expect(policy.create?).to be true
    end
  end

  describe "#update?" do
    it "allows owner to update" do
      policy = described_class.new(user, tag)
      expect(policy.update?).to be true
    end

    it "denies other users from updating" do
      policy = described_class.new(other_user, tag)
      expect(policy.update?).to be false
    end
  end

  describe "#destroy?" do
    it "allows owner to destroy" do
      policy = described_class.new(user, tag)
      expect(policy.destroy?).to be true
    end

    it "denies other users from destroying" do
      policy = described_class.new(other_user, tag)
      expect(policy.destroy?).to be false
    end
  end
end
