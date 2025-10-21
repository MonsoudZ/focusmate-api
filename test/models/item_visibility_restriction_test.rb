require "test_helper"

class ItemVisibilityRestrictionTest < ActiveSupport::TestCase
  def setup
    @coach = create_test_user(role: "coach")
    @client = create_test_user(role: "client")
    @other_coach = create_test_user(role: "coach")
    
    @coaching_relationship = CoachingRelationship.create!(
      coach: @coach,
      client: @client,
      invited_by: "coach",
      status: "active"
    )
    
    @other_relationship = CoachingRelationship.create!(
      coach: @other_coach,
      client: @client,
      invited_by: "coach",
      status: "active"
    )
    
    @list = create_test_list(@client)
    @task = create_test_task(@list, creator: @client)
    
    @restriction = ItemVisibilityRestriction.new(
      task: @task,
      coaching_relationship: @coaching_relationship
    )
  end

  test "should belong to task" do
    assert @restriction.valid?
    assert_equal @task, @restriction.task
  end

  test "should belong to coaching_relationship" do
    assert @restriction.valid?
    assert_equal @coaching_relationship, @restriction.coaching_relationship
  end

  test "should not allow duplicate restrictions" do
    @restriction.save!
    
    duplicate = ItemVisibilityRestriction.new(
      task: @task,
      coaching_relationship: @coaching_relationship
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:task_id], "has already been taken"
  end

  test "should allow same task with different relationships" do
    @restriction.save!
    
    different_relationship_restriction = ItemVisibilityRestriction.create!(
      task: @task,
      coaching_relationship: @other_relationship
    )
    
    assert different_relationship_restriction.valid?
    assert different_relationship_restriction.persisted?
  end

  test "should allow different tasks with same relationship" do
    @restriction.save!
    
    task2 = create_test_task(@list, creator: @client)
    different_task_restriction = ItemVisibilityRestriction.create!(
      task: task2,
      coaching_relationship: @coaching_relationship
    )
    
    assert different_task_restriction.valid?
    assert different_task_restriction.persisted?
  end

  test "task should be hidden from specific coach when restriction exists" do
    @restriction.save!
    
    # Check that restriction exists for this coach
    restrictions = ItemVisibilityRestriction.for_task(@task)
    assert_includes restrictions.map(&:coaching_relationship_id), @coaching_relationship.id
  end

  test "other coaches should still see task" do
    @restriction.save!
    
    # Check that no restriction exists for other coach
    restrictions = ItemVisibilityRestriction.for_coaching_relationship(@other_relationship)
    assert_not_includes restrictions.map(&:task_id), @task.id
  end

  test "client should always see their own tasks" do
    @restriction.save!
    
    # Client created the task, so they should always see it
    assert_equal @client, @task.creator
    assert_includes @client.created_tasks, @task
  end

  test "should work in addition to task visibility setting" do
    @restriction.save!
    
    # Test with different visibility settings
    @task.update!(visibility: :visible_to_all)
    assert @restriction.persisted?
    
    @task.update!(visibility: :hidden_from_coaches)
    assert @restriction.persisted?
    
    @task.update!(visibility: :private_task)
    assert @restriction.persisted?
  end

  test "should use for_task scope" do
    restriction1 = ItemVisibilityRestriction.create!(
      task: @task,
      coaching_relationship: @coaching_relationship
    )
    
    task2 = create_test_task(@list, creator: @client)
    restriction2 = ItemVisibilityRestriction.create!(
      task: task2,
      coaching_relationship: @coaching_relationship
    )
    
    task_restrictions = ItemVisibilityRestriction.for_task(@task)
    assert_includes task_restrictions, restriction1
    assert_not_includes task_restrictions, restriction2
  end

  test "should use for_coaching_relationship scope" do
    restriction1 = ItemVisibilityRestriction.create!(
      task: @task,
      coaching_relationship: @coaching_relationship
    )
    
    restriction2 = ItemVisibilityRestriction.create!(
      task: @task,
      coaching_relationship: @other_relationship
    )
    
    relationship_restrictions = ItemVisibilityRestriction.for_coaching_relationship(@coaching_relationship)
    assert_includes relationship_restrictions, restriction1
    assert_not_includes relationship_restrictions, restriction2
  end

  test "should check if visible" do
    assert @restriction.visible?
  end

  test "should handle multiple restrictions for same task" do
    @restriction.save!
    
    restriction2 = ItemVisibilityRestriction.create!(
      task: @task,
      coaching_relationship: @other_relationship
    )
    
    assert_equal 2, @task.visibility_restrictions.count
  end

  test "should handle multiple restrictions for same relationship" do
    @restriction.save!
    
    task2 = create_test_task(@list, creator: @client)
    restriction2 = ItemVisibilityRestriction.create!(
      task: task2,
      coaching_relationship: @coaching_relationship
    )
    
    assert_equal 2, @coaching_relationship.item_visibility_restrictions.count
  end

  test "should require task" do
    @restriction.task = nil
    assert_not @restriction.valid?
  end

  test "should require coaching_relationship" do
    @restriction.coaching_relationship = nil
    assert_not @restriction.valid?
  end

  test "should cascade delete when task is deleted" do
    @restriction.save!
    restriction_id = @restriction.id
    
    @task.destroy!
    
    assert_raises(ActiveRecord::RecordNotFound) do
      ItemVisibilityRestriction.find(restriction_id)
    end
  end

  test "should cascade delete when coaching_relationship is deleted" do
    @restriction.save!
    restriction_id = @restriction.id
    
    @coaching_relationship.destroy!
    
    assert_raises(ActiveRecord::RecordNotFound) do
      ItemVisibilityRestriction.find(restriction_id)
    end
  end
end

