require 'rails_helper'

RSpec.describe RecurringTemplateCreationService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe '#create!' do
    context 'with valid params' do
      it 'creates a recurring template successfully' do
        params = {
          list_id: list.id,
          title: 'Daily Standup',
          recurrence_pattern: 'daily',
          recurrence_interval: 1,
          recurrence_time: '09:00'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template).to be_persisted
        expect(template.title).to eq('Daily Standup')
        expect(template.is_recurring?).to be true
        expect(template.recurrence_pattern).to eq('daily')
        expect(template.recurrence_interval).to eq(1)
        expect(template.list_id).to eq(list.id)
        expect(template.creator_id).to eq(user.id)
      end

      it 'sets is_recurring to true' do
        params = {
          list_id: list.id,
          title: 'Weekly Meeting',
          recurrence_pattern: 'weekly',
          recurrence_time: '10:00',
          recurrence_days: [1, 3, 5]
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.is_recurring).to be true
      end

      it 'sets strict_mode to false by default' do
        params = {
          list_id: list.id,
          title: 'Template',
          recurrence_pattern: 'daily',
          recurrence_time: '08:00'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.strict_mode).to be false
      end

      it 'sets due_at from recurrence_time' do
        params = {
          list_id: list.id,
          title: 'Morning Task',
          recurrence_pattern: 'daily',
          recurrence_time: '09:00'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.due_at).to be_present
        expect(template.due_at.hour).to eq(9)
        expect(template.due_at.min).to eq(0)
      end

      it 'converts recurrence_days from day names to numbers' do
        params = {
          list_id: list.id,
          title: 'Weekday Task',
          recurrence_pattern: 'weekly',
          recurrence_days: ['monday', 'wednesday', 'friday']
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.recurrence_days).to contain_exactly(1, 3, 5)
      end

      it 'handles mixed day name and number formats' do
        params = {
          list_id: list.id,
          title: 'Task',
          recurrence_pattern: 'weekly',
          recurrence_days: ['monday', 3, 'friday']
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.recurrence_days).to contain_exactly(1, 3, 5)
      end

      it 'converts description to note' do
        params = {
          list_id: list.id,
          title: 'Task',
          description: 'This is a description',
          recurrence_pattern: 'daily',
          recurrence_time: '09:00'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.note).to eq('This is a description')
      end
    end

    context 'with invalid params' do
      it 'raises NotFoundError when list_id is missing' do
        params = { title: 'Template' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(RecurringTemplateCreationService::NotFoundError, 'List not found')
      end

      it 'raises NotFoundError when list does not exist' do
        params = { list_id: 999999, title: 'Template' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(RecurringTemplateCreationService::NotFoundError, 'List not found')
      end

      it 'raises NotFoundError when list belongs to another user' do
        other_user = create(:user)
        other_list = create(:list, user: other_user)
        params = { list_id: other_list.id, title: 'Template' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(RecurringTemplateCreationService::NotFoundError, 'List not found')
      end

      it 'raises ValidationError when title is missing' do
        params = { list_id: list.id, recurrence_pattern: 'daily' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(RecurringTemplateCreationService::ValidationError) do |error|
          expect(error.message).to eq('Validation failed')
          expect(error.details).to have_key(:title)
        end
      end

      it 'raises ValidationError with model errors' do
        params = { list_id: list.id, title: '' }
        service = described_class.new(user: user, params: params)

        expect {
          service.create!
        }.to raise_error(RecurringTemplateCreationService::ValidationError) do |error|
          expect(error.details).to be_a(Hash)
        end
      end
    end

    context 'with recurrence_time parsing' do
      it 'handles valid time format' do
        params = {
          list_id: list.id,
          title: 'Task',
          recurrence_time: '14:30'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.due_at.hour).to eq(14)
        expect(template.due_at.min).to eq(30)
      end

      it 'handles midnight time' do
        params = {
          list_id: list.id,
          title: 'Task',
          recurrence_time: '00:00'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.due_at.hour).to eq(0)
        expect(template.due_at.min).to eq(0)
      end

      it 'sets due_at to current time when recurrence_time is invalid' do
        params = {
          list_id: list.id,
          title: 'Task',
          recurrence_time: 'invalid'
        }
        service = described_class.new(user: user, params: params)

        template = service.create!

        expect(template.due_at).to be_within(1.minute).of(Time.current)
      end
    end
  end

  describe 'ValidationError' do
    it 'stores message and details' do
      error = RecurringTemplateCreationService::ValidationError.new('Test', { field: ['error'] })

      expect(error.message).to eq('Test')
      expect(error.details).to eq({ field: ['error'] })
    end
  end

  describe 'NotFoundError' do
    it 'is a StandardError' do
      expect(RecurringTemplateCreationService::NotFoundError.new).to be_a(StandardError)
    end
  end
end
