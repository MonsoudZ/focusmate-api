# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskVisibilityService do
  let(:list_owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: list_owner) }
  let(:task) { create(:task, list: list, creator: list_owner) }

  describe '#change_visibility!' do
    context 'when user is the list owner' do
      it 'sets task to visible_to_all' do
        service = described_class.new(task: task, user: list_owner)

        result = service.change_visibility!(visibility: 'visible_to_all')

        expect(result).to eq(task)
        expect(task.reload.visibility).to eq('visible_to_all')
      end

      it 'sets task to private_task' do
        service = described_class.new(task: task, user: list_owner)

        result = service.change_visibility!(visibility: 'private_task')

        expect(result).to eq(task)
        expect(task.reload.visibility).to eq('private_task')
      end
    end

    context 'when user is not the list owner' do
      it 'raises UnauthorizedError' do
        service = described_class.new(task: task, user: other_user)

        expect {
          service.change_visibility!(visibility: 'private_task')
        }.to raise_error(
               TaskVisibilityService::UnauthorizedError,
               'Only list owner can modify task visibility'
             )
      end

      it 'does not change the visibility' do
        initial_visibility = task.visibility
        service = described_class.new(task: task, user: other_user)

        expect {
          service.change_visibility!(visibility: 'private_task')
        }.to raise_error(TaskVisibilityService::UnauthorizedError)

        expect(task.reload.visibility).to eq(initial_visibility)
      end
    end

    context 'when visibility value is invalid' do
      it 'raises ValidationError' do
        service = described_class.new(task: task, user: list_owner)

        expect {
          service.change_visibility!(visibility: 'invalid')
        }.to raise_error(
               TaskVisibilityService::ValidationError,
               'Invalid visibility setting'
             )
      end

      it 'does not change the visibility' do
        initial_visibility = task.visibility
        service = described_class.new(task: task, user: list_owner)

        expect {
          service.change_visibility!(visibility: 'invalid')
        }.to raise_error(TaskVisibilityService::ValidationError)

        expect(task.reload.visibility).to eq(initial_visibility)
      end
    end
  end
end
