# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:record) { double('record') }
  let(:policy) { described_class.new(user, record) }

  describe '#initialize' do
    it 'assigns user and record' do
      expect(policy.user).to eq(user)
      expect(policy.record).to eq(record)
    end
  end

  describe 'default policy methods' do
    it '#index? returns false by default' do
      expect(policy.index?).to be false
    end

    it '#show? returns false by default' do
      expect(policy.show?).to be false
    end

    it '#create? returns false by default' do
      expect(policy.create?).to be false
    end

    it '#new? delegates to create?' do
      expect(policy.new?).to eq(policy.create?)
    end

    it '#update? returns false by default' do
      expect(policy.update?).to be false
    end

    it '#edit? delegates to update?' do
      expect(policy.edit?).to eq(policy.update?)
    end

    it '#destroy? returns false by default' do
      expect(policy.destroy?).to be false
    end
  end

  describe 'Scope' do
    let(:scope) { double('scope') }
    let(:policy_scope) { ApplicationPolicy::Scope.new(user, scope) }

    it 'initializes with user and scope' do
      expect(policy_scope.instance_variable_get(:@user)).to eq(user)
      expect(policy_scope.instance_variable_get(:@scope)).to eq(scope)
    end

    it 'raises NoMethodError when resolve is not implemented' do
      expect {
        policy_scope.resolve
      }.to raise_error(NoMethodError, /You must define #resolve/)
    end
  end
end
