require 'rails_helper'

RSpec.describe RecurringTemplateUpdateService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:template) do
    create(:task,
           list: list,
           creator: user,
           title: 'Original Title',
           note: 'Original Note',
           is_recurring: true,
           recurring_template_id: nil,
           recurrence_pattern: 'daily',
           recurrence_interval: 1,
           recurrence_time: '09:00',
           due_at: Time.current)
  end

  describe '#update!' do
    context 'with valid params' do
      it 'updates the template successfully' do
        service = described_class.new(template: template, params: { title: 'Updated Title' })

        result = service.update!

        expect(result).to eq(template)
        expect(template.reload.title).to eq('Updated Title')
      end

      it 'updates multiple attributes' do
        service = described_class.new(template: template, params: {
          title: 'New Title',
          note: 'New Note',
          recurrence_interval: 2
        })

        service.update!

        template.reload
        expect(template.title).to eq('New Title')
        expect(template.note).to eq('New Note')
        expect(template.recurrence_interval).to eq(2)
      end

      it 'converts description to note' do
        service = described_class.new(template: template, params: {
          description: 'Converted Description'
        })

        service.update!

        expect(template.reload.note).to eq('Converted Description')
      end

      it 'updates recurrence_time' do
        service = described_class.new(template: template, params: {
          recurrence_time: '15:30'
        })

        service.update!

        expect(template.reload.due_at.hour).to eq(15)
        expect(template.reload.due_at.min).to eq(30)
      end

      it 'updates recurrence_days' do
        service = described_class.new(template: template, params: {
          recurrence_days: ['monday', 'friday']
        })

        service.update!

        expect(template.reload.recurrence_days).to contain_exactly(1, 5)
      end
    end

    context 'propagating changes to future instances' do
      let!(:past_instance) do
        create(:task,
               list: list,
               creator: user,
               title: 'Original Title',
               note: 'Original Note',
               recurring_template_id: template.id,
               due_at: 1.day.ago,
               status: :pending)
      end

      let!(:future_incomplete_instance) do
        create(:task,
               list: list,
               creator: user,
               title: 'Original Title',
               note: 'Original Note',
               recurring_template_id: template.id,
               due_at: 1.day.from_now,
               status: :pending)
      end

      let!(:future_completed_instance) do
        create(:task,
               list: list,
               creator: user,
               title: 'Original Title',
               note: 'Original Note',
               recurring_template_id: template.id,
               due_at: 2.days.from_now,
               status: :done)
      end

      it 'propagates title changes to future incomplete instances' do
        service = described_class.new(template: template, params: { title: 'New Title' })

        service.update!

        expect(past_instance.reload.title).to eq('Original Title')
        expect(future_incomplete_instance.reload.title).to eq('New Title')
        expect(future_completed_instance.reload.title).to eq('Original Title')
      end

      it 'propagates note changes to future incomplete instances' do
        service = described_class.new(template: template, params: { note: 'New Note' })

        service.update!

        expect(past_instance.reload.note).to eq('Original Note')
        expect(future_incomplete_instance.reload.note).to eq('New Note')
        expect(future_completed_instance.reload.note).to eq('Original Note')
      end

      it 'propagates both title and note changes' do
        service = described_class.new(template: template, params: {
          title: 'New Title',
          note: 'New Note'
        })

        service.update!

        expect(future_incomplete_instance.reload.title).to eq('New Title')
        expect(future_incomplete_instance.reload.note).to eq('New Note')
      end

      it 'does not propagate recurrence_interval changes' do
        service = described_class.new(template: template, params: {
          recurrence_interval: 2
        })

        service.update!

        expect(template.reload.recurrence_interval).to eq(2)
        # Instances should not have recurrence_interval changed
      end

      it 'does not propagate when only non-title/note fields change' do
        service = described_class.new(template: template, params: {
          recurrence_interval: 2,
          recurrence_pattern: 'weekly',
          recurrence_days: [1, 3, 5]
        })

        service.update!

        expect(future_incomplete_instance.reload.title).to eq('Original Title')
      end
    end

    context 'with invalid params' do
      it 'raises ValidationError when validation fails' do
        service = described_class.new(template: template, params: { title: '' })

        expect {
          service.update!
        }.to raise_error(RecurringTemplateUpdateService::ValidationError) do |error|
          expect(error.message).to eq('Validation failed')
          expect(error.details).to have_key(:title)
        end
      end

      it 'does not update the template on validation failure' do
        service = described_class.new(template: template, params: { title: '' })

        expect {
          service.update!
        }.to raise_error(RecurringTemplateUpdateService::ValidationError)

        expect(template.reload.title).to eq('Original Title')
      end
    end

    context 'maintaining recurring template attributes' do
      it 'always sets is_recurring to true' do
        service = described_class.new(template: template, params: { title: 'Updated' })

        service.update!

        expect(template.reload.is_recurring).to be true
      end

      it 'always sets recurring_template_id to nil' do
        service = described_class.new(template: template, params: { title: 'Updated' })

        service.update!

        expect(template.reload.recurring_template_id).to be_nil
      end

      it 'sets strict_mode to false if not provided' do
        template.update_column(:strict_mode, true)
        service = described_class.new(template: template, params: { title: 'Updated' })

        service.update!

        expect(template.reload.strict_mode).to be false
      end
    end
  end

  describe 'ValidationError' do
    it 'stores message and details' do
      error = RecurringTemplateUpdateService::ValidationError.new('Test', { field: ['error'] })

      expect(error.message).to eq('Test')
      expect(error.details).to eq({ field: ['error'] })
    end
  end
end
