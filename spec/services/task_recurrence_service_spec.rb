require 'rails_helper'

RSpec.describe TaskRecurrenceService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:task) { create(:task, list: list, creator: user) }
  let(:service) { described_class.new(task) }

  describe '#calculate_next_due_date' do
    context 'when task is not recurring' do
      it 'returns nil' do
        expect(service.calculate_next_due_date).to be_nil
      end
    end

    context 'when task is recurring' do
      before do
        task.update!(
          is_recurring: true,
          recurrence_pattern: 'daily',
          recurrence_time: Time.current
        )
      end

      it 'delegates to appropriate calculator' do
        expect(service).to receive(:calculate_daily_recurrence)
        service.calculate_next_due_date
      end
    end
  end

  describe '#generate_next_instance' do
    context 'when task is not recurring' do
      it 'returns nil' do
        expect(service.generate_next_instance).to be_nil
      end
    end

    context 'when task is recurring' do
      before do
        task.update!(
          is_recurring: true,
          recurrence_pattern: 'daily',
          recurrence_time: Time.current
        )
      end

      it 'creates a new task instance' do
        instance = service.generate_next_instance
        expect(instance).to be_a(Task)
        expect(instance.template_id).to eq(task.id)
        expect(instance.is_recurring).to be false
      end
    end
  end

  describe 'recurrence calculators' do
    before { task.update!(is_recurring: true) }

    describe '#calculate_daily_recurrence' do
      before { task.update!(recurrence_pattern: 'daily', recurrence_time: Time.current) }

      it 'calculates next daily occurrence' do
        result = service.send(:calculate_daily_recurrence)
        expect(result).to be > Time.current
      end
    end

    describe '#calculate_weekly_recurrence' do
      before do
        task.update!(
          recurrence_pattern: 'weekly',
          recurrence_days: [ 1, 3, 5 ],
          recurrence_time: Time.current
        )
      end

      it 'calculates next weekly occurrence' do
        result = service.send(:calculate_weekly_recurrence)
        expect(result).to be > Time.current
      end
    end

    describe '#calculate_monthly_recurrence' do
      before do
        task.update!(
          recurrence_pattern: 'monthly',
          recurrence_time: Time.current
        )
      end

      it 'calculates next monthly occurrence' do
        result = service.send(:calculate_monthly_recurrence)
        expect(result).to be > Time.current
      end
    end

    describe '#calculate_yearly_recurrence' do
      before do
        task.update!(
          recurrence_pattern: 'yearly',
          recurrence_time: Time.current
        )
      end

      it 'calculates next yearly occurrence' do
        result = service.send(:calculate_yearly_recurrence)
        expect(result).to be > Time.current
      end
    end
  end
end
