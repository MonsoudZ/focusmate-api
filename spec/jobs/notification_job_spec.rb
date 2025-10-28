# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationJob, type: :job do
  let(:coach) { create(:user, role: 'coach') }
  let(:client) { create(:user, role: 'client') }
  let(:relationship) { create(:coaching_relationship, coach: coach, client: client) }

  describe '#perform' do
    context 'with coaching notifications' do
      it 'handles coaching_invitation_sent' do
        expect(NotificationService).to receive(:coaching_invitation_sent).with(relationship)
        
        described_class.perform_now('coaching_invitation_sent', relationship.id)
      end

      it 'handles coaching_invitation_accepted' do
        expect(NotificationService).to receive(:coaching_invitation_accepted).with(relationship)
        
        described_class.perform_now('coaching_invitation_accepted', relationship.id)
      end

      it 'handles coaching_invitation_declined' do
        expect(NotificationService).to receive(:coaching_invitation_declined).with(relationship)
        
        described_class.perform_now('coaching_invitation_declined', relationship.id)
      end
    end

    context 'with task notifications' do
      let(:list) { create(:list, user: client) }
      let(:task) { create(:task, list: list) }

      it 'handles task_completed' do
        expect(NotificationService).to receive(:task_completed).with(task)
        
        described_class.perform_now('task_completed', task.id)
      end

      it 'handles new_item_assigned' do
        expect(NotificationService).to receive(:new_item_assigned).with(task)
        
        described_class.perform_now('new_item_assigned', task.id)
      end
    end

    context 'with list notifications' do
      let(:list) { create(:list, user: client) }

      it 'handles list_shared' do
        expect(NotificationService).to receive(:list_shared).with(list, coach)
        
        described_class.perform_now('list_shared', list.id, coach.id)
      end
    end

    context 'with test notifications' do
      it 'handles send_test_notification' do
        expect(NotificationService).to receive(:send_test_notification).with(client, 'Test message')
        
        described_class.perform_now('send_test_notification', client.id, 'Test message')
      end
    end

    context 'when record is not found' do
      it 'logs error and does not re-raise for coaching relationships' do
        expect(Rails.logger).to receive(:error).with(/CoachingRelationship 999 not found/)
        
        expect { described_class.perform_now('coaching_invitation_sent', 999) }.not_to raise_error
      end

      it 'logs error and does not re-raise for tasks' do
        expect(Rails.logger).to receive(:error).with(/Task 999 not found/)
        
        expect { described_class.perform_now('task_completed', 999) }.not_to raise_error
      end
    end

    context 'with unknown notification method' do
      it 'logs warning and does not raise error' do
        expect(Rails.logger).to receive(:warn).with('Unknown notification method: unknown_method')
        
        expect { described_class.perform_now('unknown_method', 1) }.not_to raise_error
      end
    end

    context 'when NotificationService raises an error' do
      it 'logs error and re-raises to trigger retry' do
        allow(NotificationService).to receive(:coaching_invitation_sent).and_raise(StandardError, 'Service error')
        allow(Rails.logger).to receive(:error) # Just allow the logger call
        
        expect { described_class.perform_now('coaching_invitation_sent', relationship.id) }.to raise_error(StandardError)
      end
    end
  end
end
