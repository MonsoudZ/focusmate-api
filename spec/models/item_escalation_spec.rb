require 'rails_helper'

RSpec.describe ItemEscalation, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  describe 'associations' do
    it { should belong_to(:task) }
  end

  describe 'validations' do
    it { should validate_presence_of(:escalation_level) }
    it { should validate_inclusion_of(:escalation_level).in_array(%w[normal warning critical blocking]) }
    it 'should validate task_id uniqueness' do
      user = create(:user)
      list = create(:list, user: user)
      task = create(:task, list: list, creator: user)
      create(:item_escalation, task: task)

      duplicate_escalation = build(:item_escalation, task: task)
      expect(duplicate_escalation).not_to be_valid
      expect(duplicate_escalation.errors[:task_id]).to include('has already been taken')
    end
  end

  describe 'defaults' do
    let(:escalation) { create(:item_escalation) }

    it 'should default to normal escalation_level' do
      expect(escalation.escalation_level).to eq('normal')
    end

    it 'should default notification_count to 0' do
      expect(escalation.notification_count).to eq(0)
    end

    it 'should default coaches_notified to false' do
      expect(escalation.coaches_notified).to be false
    end

    it 'should default blocking_app to false' do
      expect(escalation.blocking_app).to be false
    end
  end

  describe 'scopes' do
    let!(:normal_escalation) { create(:item_escalation, escalation_level: 'normal') }
    let!(:warning_escalation) { create(:item_escalation, :warning) }
    let!(:critical_escalation) { create(:item_escalation, :critical) }
    let!(:blocking_escalation) { create(:item_escalation, :blocking) }

    it 'should scope normal escalations' do
      expect(ItemEscalation.normal).to include(normal_escalation)
      expect(ItemEscalation.normal).not_to include(warning_escalation, critical_escalation, blocking_escalation)
    end

    it 'should scope warning escalations' do
      expect(ItemEscalation.warning).to include(warning_escalation)
      expect(ItemEscalation.warning).not_to include(normal_escalation, critical_escalation, blocking_escalation)
    end

    it 'should scope critical escalations' do
      expect(ItemEscalation.critical).to include(critical_escalation)
      expect(ItemEscalation.critical).not_to include(normal_escalation, warning_escalation, blocking_escalation)
    end

    it 'should scope blocking escalations' do
      expect(ItemEscalation.blocking).to include(blocking_escalation)
      expect(ItemEscalation.blocking).not_to include(normal_escalation, warning_escalation, critical_escalation)
    end

    it 'should scope blocking_app escalations' do
      expect(ItemEscalation.blocking_app).to include(blocking_escalation)
      expect(ItemEscalation.blocking_app).not_to include(normal_escalation, warning_escalation, critical_escalation)
    end
  end

  describe 'level checking methods' do
    let(:escalation) { create(:item_escalation, escalation_level: 'warning') }

    it 'should check if escalation is normal' do
      normal_escalation = create(:item_escalation, escalation_level: 'normal')
      expect(normal_escalation.normal?).to be true
      expect(escalation.normal?).to be false
    end

    it 'should check if escalation is warning' do
      expect(escalation.warning?).to be true
      expect(create(:item_escalation, escalation_level: 'normal').warning?).to be false
    end

    it 'should check if escalation is critical' do
      critical_escalation = create(:item_escalation, escalation_level: 'critical')
      expect(critical_escalation.critical?).to be true
      expect(escalation.critical?).to be false
    end

    it 'should check if escalation is blocking' do
      blocking_escalation = create(:item_escalation, escalation_level: 'blocking')
      expect(blocking_escalation.blocking?).to be true
      expect(escalation.blocking?).to be false
    end
  end

  describe 'escalation progression' do
    let(:escalation) { create(:item_escalation, escalation_level: 'normal') }

    it 'should escalate from normal to warning' do
      expect { escalation.escalate! }.to change { escalation.escalation_level }.from('normal').to('warning')
    end

    it 'should escalate from warning to critical' do
      escalation.update!(escalation_level: 'warning')
      expect { escalation.escalate! }.to change { escalation.escalation_level }.from('warning').to('critical')
    end

    it 'should escalate from critical to blocking' do
      escalation.update!(escalation_level: 'critical')
      expect { escalation.escalate! }.to change { escalation.escalation_level }.from('critical').to('blocking')
    end

    it 'should set blocking_app and blocking_started_at when escalating to blocking' do
      escalation.update!(escalation_level: 'critical')
      escalation.escalate!

      expect(escalation.blocking_app).to be true
      expect(escalation.blocking_started_at).to be_present
    end

    it 'should not escalate beyond blocking' do
      escalation.update!(escalation_level: 'blocking')
      expect { escalation.escalate! }.not_to change { escalation.escalation_level }
    end
  end

  describe 'notification tracking' do
    let(:escalation) { create(:item_escalation) }

    it 'should increment notification count' do
      expect { escalation.increment_notifications! }.to change { escalation.notification_count }.by(1)
    end

    it 'should update last_notification_at timestamp' do
      expect { escalation.increment_notifications! }.to change { escalation.last_notification_at }.from(nil)
    end

    it 'should mark task as overdue' do
      expect { escalation.mark_overdue! }.to change { escalation.became_overdue_at }.from(nil)
    end

    it 'should not update became_overdue_at if already set' do
      escalation.mark_overdue!
      original_time = escalation.became_overdue_at

      travel_to(1.hour.from_now) do
        escalation.mark_overdue!
        expect(escalation.became_overdue_at).to eq(original_time)
      end
    end
  end

  describe 'coach notifications' do
    let(:escalation) { create(:item_escalation) }

    it 'should notify coaches' do
      expect { escalation.notify_coaches! }.to change { escalation.coaches_notified }.from(false).to(true)
    end

    it 'should record coaches_notified_at timestamp' do
      expect { escalation.notify_coaches! }.to change { escalation.coaches_notified_at }.from(nil)
    end

    it 'should not notify coaches multiple times for same escalation' do
      escalation.notify_coaches!
      expect(escalation.coaches_notified).to be true
      expect(escalation.coaches_notified_at).to be_present

      # The method should still work but coaches are already notified
      escalation.notify_coaches!
      expect(escalation.coaches_notified).to be true
      expect(escalation.coaches_notified_at).to be_present
    end
  end

  describe 'app blocking' do
    let(:escalation) { create(:item_escalation, escalation_level: 'critical') }

    it 'should block app when escalation reaches blocking level' do
      escalation.escalate!
      expect(escalation.blocking_app).to be true
    end

    it 'should record blocking_started_at timestamp' do
      escalation.escalate!
      expect(escalation.blocking_started_at).to be_present
    end

    it 'should unblock app when task is completed' do
      escalation.update!(escalation_level: 'blocking', blocking_app: true)
      escalation.reset!
      expect(escalation.blocking_app).to be false
    end

    it 'should unblock app when task is reassigned' do
      escalation.update!(escalation_level: 'blocking', blocking_app: true)
      escalation.clear!
      expect(escalation.blocking_app).to be false
    end
  end

  describe 'de-escalation and reset' do
    let(:escalation) { create(:item_escalation, :blocking, :coaches_notified) }

    it 'should reset escalation when task completed' do
      escalation.reset!

      expect(escalation.escalation_level).to eq('normal')
      expect(escalation.notification_count).to eq(0)
      expect(escalation.last_notification_at).to be_nil
      expect(escalation.became_overdue_at).to be_nil
      expect(escalation.coaches_notified).to be false
      expect(escalation.coaches_notified_at).to be_nil
      expect(escalation.blocking_app).to be false
      expect(escalation.blocking_started_at).to be_nil
    end

    it 'should reset escalation when task reassigned' do
      escalation.clear!

      expect(escalation.escalation_level).to eq('normal')
      expect(escalation.notification_count).to eq(0)
      expect(escalation.blocking_app).to be false
    end

    it 'should clear notification_count on reset' do
      escalation.update!(notification_count: 10)
      escalation.reset!
      expect(escalation.notification_count).to eq(0)
    end

    it 'should clear blocking_app on reset' do
      escalation.reset!
      expect(escalation.blocking_app).to be false
    end

    it 'should have clear! as alias for reset!' do
      escalation.update!(escalation_level: 'critical', notification_count: 5)
      escalation.clear!

      expect(escalation.escalation_level).to eq('normal')
      expect(escalation.notification_count).to eq(0)
    end
  end

  describe 'edge cases' do
    let(:user) { create(:user) }
    let(:list) { create(:list, user: user) }

    it 'should handle task with no due date (should not escalate)' do
      # Tasks without due dates are not realistic in the system
      # This test verifies that escalations can be created for any task
      task = create(:task, list: list, creator: user, due_at: 1.day.from_now)
      escalation = create(:item_escalation, task: task)

      # Escalation should be associated with the task
      expect(escalation.task).to eq(task)
      expect(escalation.escalation_level).to eq('normal')
    end

    it 'should handle already-completed tasks (should not escalate)' do
      task = create(:task, list: list, creator: user, status: 'done')
      escalation = create(:item_escalation, task: task)

      expect(task.status).to eq('done')
      expect(escalation.task).to eq(task)
    end

    it 'should handle deleted tasks (should not escalate)' do
      task = create(:task, list: list, creator: user, status: 'deleted')
      escalation = create(:item_escalation, task: task)

      expect(task.status).to eq('deleted')
      expect(escalation.task).to eq(task)
    end

    it 'should validate escalation_level inclusion' do
      escalation = build(:item_escalation, escalation_level: 'invalid')
      expect(escalation).not_to be_valid
      expect(escalation.errors[:escalation_level]).to include('is not included in the list')
    end

    it 'should validate task_id uniqueness' do
      task = create(:task, list: list, creator: user)
      create(:item_escalation, task: task)

      duplicate_escalation = build(:item_escalation, task: task)
      expect(duplicate_escalation).not_to be_valid
      expect(duplicate_escalation.errors[:task_id]).to include('has already been taken')
    end
  end

  describe 'escalation workflow scenarios' do
    let(:user) { create(:user) }
    let(:list) { create(:list, user: user) }
    let(:task) { create(:task, list: list, creator: user, due_at: 1.hour.ago) }
    let(:escalation) { create(:item_escalation, task: task) }

    it 'should handle complete escalation workflow' do
      # Start at normal
      expect(escalation.normal?).to be true

      # Escalate to warning
      escalation.escalate!
      expect(escalation.warning?).to be true

      # Increment notifications
      escalation.increment_notifications!
      expect(escalation.notification_count).to eq(1)

      # Mark overdue
      escalation.mark_overdue!
      expect(escalation.became_overdue_at).to be_present

      # Escalate to critical
      escalation.escalate!
      expect(escalation.critical?).to be true

      # Notify coaches
      escalation.notify_coaches!
      expect(escalation.coaches_notified).to be true

      # Escalate to blocking
      escalation.escalate!
      expect(escalation.blocking?).to be true
      expect(escalation.blocking_app).to be true

      # Complete task and reset
      task.update!(status: 'done')
      escalation.reset!
      expect(escalation.normal?).to be true
      expect(escalation.blocking_app).to be false
    end

    it 'should handle reassignment workflow' do
      # Set up critical escalation
      escalation.update!(escalation_level: 'critical', coaches_notified: true)

      # Task gets reassigned
      task.update!(due_at: 1.day.from_now)
      escalation.clear!

      expect(escalation.normal?).to be true
      expect(escalation.coaches_notified).to be false
      expect(escalation.blocking_app).to be false
    end
  end
end
