require 'rails_helper'

RSpec.describe RecurringTemplateDeletionService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:template) do
    create(:task,
           list: list,
           creator: user,
           is_recurring: true,
           recurring_template_id: nil,
           recurrence_pattern: 'daily',
           recurrence_time: '09:00',
           due_at: Time.current)
  end

  describe '#delete!' do
    context 'when delete_instances is false' do
      it 'deletes only the template' do
        instance1 = create(:task, list: list, creator: user, recurring_template_id: template.id, due_at: 1.day.from_now, title: 'Instance 1')
        instance2 = create(:task, list: list, creator: user, recurring_template_id: template.id, due_at: 2.days.from_now, title: 'Instance 2')

        service = described_class.new(template: template, delete_instances: false)

        result = service.delete!

        expect(result).to be true
        expect(Task.exists?(template.id)).to be false
        expect(Task.exists?(instance1.id)).to be true
        expect(Task.exists?(instance2.id)).to be true
      end

      it 'handles template with no instances' do
        service = described_class.new(template: template, delete_instances: false)

        result = service.delete!

        expect(result).to be true
        expect(Task.exists?(template.id)).to be false
      end

      it 'accepts string "false"' do
        instance = create(:task, list: list, creator: user, recurring_template_id: template.id, due_at: 1.day.from_now, title: 'Instance')

        service = described_class.new(template: template, delete_instances: 'false')

        service.delete!

        expect(Task.exists?(instance.id)).to be true
      end

      it 'accepts nil as false' do
        instance = create(:task, list: list, creator: user, recurring_template_id: template.id, due_at: 1.day.from_now, title: 'Instance')

        service = described_class.new(template: template, delete_instances: nil)

        service.delete!

        expect(Task.exists?(instance.id)).to be true
      end
    end

    context 'when delete_instances is true' do
      it 'deletes template and all its instances' do
        instance1 = create(:task, list: list, recurring_template_id: template.id)
        instance2 = create(:task, list: list, recurring_template_id: template.id)

        service = described_class.new(template: template, delete_instances: true)

        result = service.delete!

        expect(result).to be true
        expect(Task.exists?(template.id)).to be false
        expect(Task.exists?(instance1.id)).to be false
        expect(Task.exists?(instance2.id)).to be false
      end

      it 'accepts string "true"' do
        instance = create(:task, list: list, recurring_template_id: template.id)

        service = described_class.new(template: template, delete_instances: 'true')

        service.delete!

        expect(Task.exists?(instance.id)).to be false
      end

      it 'accepts "1" as true' do
        instance = create(:task, list: list, recurring_template_id: template.id)

        service = described_class.new(template: template, delete_instances: '1')

        service.delete!

        expect(Task.exists?(instance.id)).to be false
      end

      it 'deletes only instances of this template' do
        other_template = create(:task,
                               list: list,
                               creator: user,
                               title: 'Other Template',
                               is_recurring: true,
                               recurring_template_id: nil,
                               recurrence_pattern: 'weekly',
                               recurrence_time: '10:00',
                               recurrence_days: [1, 3],
                               due_at: Time.current)
        other_instance = create(:task, list: list, creator: user, title: 'Other Instance', recurring_template_id: other_template.id, due_at: Time.current)
        this_instance = create(:task, list: list, creator: user, title: 'This Instance', recurring_template_id: template.id, due_at: Time.current)

        service = described_class.new(template: template, delete_instances: true)

        service.delete!

        expect(Task.exists?(other_template.id)).to be true
        expect(Task.exists?(other_instance.id)).to be true
        expect(Task.exists?(this_instance.id)).to be false
      end

      it 'handles template with many instances' do
        instances = create_list(:task, 10, list: list, recurring_template_id: template.id)

        service = described_class.new(template: template, delete_instances: true)

        service.delete!

        instances.each do |instance|
          expect(Task.exists?(instance.id)).to be false
        end
      end
    end
  end
end
