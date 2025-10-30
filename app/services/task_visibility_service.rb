# frozen_string_literal: true

class TaskVisibilityService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError; end
  class NotFoundError < StandardError; end

  def initialize(task:, user:)
    @task = task
    @user = user
  end

  def change_visibility!(visibility:)
    validate_authorization!
    validate_visibility_value!(visibility)
    @task.update!(visibility: visibility)
    @task
  end

  def toggle_for_coach!(coach_id:, visible:)
    validate_authorization!

    coach = find_coach(coach_id)
    relationship = find_relationship(coach)

    if visible
      @task.show_to!(relationship)
    else
      @task.hide_from!(relationship)
    end

    @task
  end

  def submit_explanation!(missed_reason:)
    validate_authorization!
    validate_explanation_support!

    attrs = build_explanation_attrs(missed_reason)
    @task.update!(attrs)
    @task
  end

  private

  def validate_authorization!
    unless @task.list.user_id == @user.id
      raise UnauthorizedError, "Only list owner can modify task visibility"
    end
  end

  def validate_visibility_value!(visibility)
    unless Task.visibilities.keys.include?(visibility)
      raise ValidationError, "Invalid visibility setting"
    end
  end

  def find_coach(coach_id)
    User.find(coach_id)
  rescue ActiveRecord::RecordNotFound
    raise NotFoundError, "User not found"
  end

  def find_relationship(coach)
    relationship = @user.relationship_with_coach(coach)
    raise NotFoundError, "Coaching relationship not found" unless relationship
    relationship
  end

  def validate_explanation_support!
    return if Task.column_names.include?("missed_reason")
    raise ValidationError, "Task does not support missed-explanation fields"
  end

  def build_explanation_attrs(missed_reason)
    attrs = {}
    attrs[:missed_reason] = missed_reason.to_s if Task.column_names.include?("missed_reason")
    attrs[:missed_reason_submitted_at] = Time.current if Task.column_names.include?("missed_reason_submitted_at")
    attrs
  end
end
