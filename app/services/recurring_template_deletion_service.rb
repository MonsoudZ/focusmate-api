# frozen_string_literal: true

class RecurringTemplateDeletionService
  def initialize(template:, delete_instances: false)
    @template = template
    @delete_instances = ActiveModel::Type::Boolean.new.cast(delete_instances)
  end

  def delete!
    if @delete_instances
      delete_all_instances
    else
      unlink_instances
    end
    @template.destroy!
    true
  end

  private

  def delete_all_instances
    Task.where(recurring_template_id: @template.id).find_each(&:destroy!)
  end

  def unlink_instances
    # Remove the foreign key reference before deleting template
    # This prevents Rails' dependent: :destroy from cascading
    Task.where(recurring_template_id: @template.id).update_all(recurring_template_id: nil)
  end
end
