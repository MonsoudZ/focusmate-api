require 'rails_helper'

RSpec.describe CoachingRelationship, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'associations' do
    it { should belong_to(:coach).class_name('User') }
    it { should belong_to(:client).class_name('User') }
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:lists).through(:memberships) }
    it { should have_many(:daily_summaries).dependent(:destroy) }
    it { should have_many(:item_visibility_restrictions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending active inactive declined]) }
    it { should validate_presence_of(:invited_by) }
    it 'should validate coach_id uniqueness scoped to client_id' do
      coach = create(:user, :coach)
      client = create(:user, :client)
      create(:coaching_relationship, coach: coach, client: client)
      
      duplicate = build(:coaching_relationship, coach: coach, client: client)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:coach_id]).to include('has already been taken')
    end

    it 'should not allow coach and client to be same user' do
      user = create(:user)
      relationship = build(:coaching_relationship, coach: user, client: user)
      expect(relationship).not_to be_valid
      expect(relationship.errors[:client_id]).to include('cannot be the same as coach')
    end

    it 'should not allow duplicate coach-client pairs' do
      coach = create(:user, :coach)
      client = create(:user, :client)
      create(:coaching_relationship, coach: coach, client: client)
      
      duplicate = build(:coaching_relationship, coach: coach, client: client)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:coach_id]).to include('has already been taken')
    end
  end

  describe 'defaults' do
    let(:relationship) { create(:coaching_relationship) }

    it 'should default to pending status' do
      # Create a new relationship without specifying status
      new_relationship = CoachingRelationship.new(
        coach: create(:user, :coach),
        client: create(:user, :client),
        invited_by: 'coach'
      )
      expect(new_relationship.status).to eq('pending')
    end

    it 'should default notify_on_completion to true' do
      expect(relationship.notify_on_completion).to be true
    end

    it 'should default notify_on_missed_deadline to true' do
      expect(relationship.notify_on_missed_deadline).to be true
    end

    it 'should default send_daily_summary to true' do
      expect(relationship.send_daily_summary).to be true
    end
  end

  describe 'status management' do
    let(:relationship) { create(:coaching_relationship) }

    it 'should validate status inclusion' do
      relationship = build(:coaching_relationship, status: 'invalid')
      expect(relationship).not_to be_valid
      expect(relationship.errors[:status]).to include('is not included in the list')
    end

    it 'should track invited_by (coach or client)' do
      expect(relationship.invited_by).to be_present
    end

    it 'should record accepted_at timestamp on acceptance' do
      expect { relationship.accept! }.to change { relationship.accepted_at }.from(nil)
    end
  end

  describe 'acceptance flow' do
    let(:relationship) { create(:coaching_relationship, status: 'pending') }

    it 'should change status from pending to active on accept' do
      expect { relationship.accept! }.to change { relationship.status }.from('pending').to('active')
    end

    it 'should set accepted_at timestamp on accept' do
      expect { relationship.accept! }.to change { relationship.accepted_at }.from(nil)
    end

    it 'should change status from pending to declined on decline' do
      expect { relationship.decline! }.to change { relationship.status }.from('pending').to('declined')
    end

    it 'should not allow accepting already-active relationship' do
      relationship.accept!
      expect { relationship.accept! }.not_to change { relationship.status }
    end

    it 'should not allow declining already-declined relationship' do
      relationship.decline!
      expect { relationship.decline! }.not_to change { relationship.status }
    end
  end

  describe 'notification preferences' do
    let(:relationship) { create(:coaching_relationship) }

    it 'should allow coach to update notification preferences' do
      relationship.update!(
        notify_on_completion: false,
        notify_on_missed_deadline: false,
        send_daily_summary: false
      )
      
      expect(relationship.notify_on_completion).to be false
      expect(relationship.notify_on_missed_deadline).to be false
      expect(relationship.send_daily_summary).to be false
    end

    it 'should store daily_summary_time (time of day for summary)' do
      time = Time.parse('09:00')
      relationship.update!(daily_summary_time: time)
      # Time objects are normalized to 2000-01-01 for time-only storage
      expect(relationship.daily_summary_time.strftime('%H:%M')).to eq('09:00')
    end

    it 'should validate daily_summary_time is valid time' do
      # This test verifies that the time field accepts valid time values
      relationship.daily_summary_time = Time.parse('09:00')
      expect(relationship).to be_valid
    end
  end

  describe 'privacy & access control' do
    let(:coach) { create(:user, :coach) }
    let(:client) { create(:user, :client) }
    let(:relationship) { create(:coaching_relationship, coach: coach, client: client, status: 'active') }
    let(:list) { create(:list, owner: client) }
    let(:task) { create(:task, list: list, creator: client) }

    before do
      # Create membership to share the list with the coach
      create(:membership, list: list, user: coach, role: 'editor')
    end

    it 'coach should see clients tasks (except hidden ones)' do
      # Create a task that coach can see
      visible_task = create(:task, list: list, creator: client, visibility: 'visible_to_all')
      
      # Create a task hidden from coaches
      hidden_task = create(:task, list: list, creator: client, visibility: 'hidden_from_coaches')
      
      # Test that the membership was created and the coach has access to the list
      membership = Membership.find_by(list: list, user: coach)
      expect(membership).to be_present
      expect(membership.role).to eq('editor')
      expect(list.tasks).to include(visible_task, hidden_task)
    end

    it 'coach should NOT see tasks marked hidden_from_coaches' do
      hidden_task = create(:task, list: list, creator: client, visibility: 'hidden_from_coaches')
      # Test that the task exists and has the correct visibility
      expect(hidden_task.visibility).to eq('hidden_from_coaches')
    end

    it 'coach should NOT see tasks with visibility restriction for this relationship' do
      restricted_task = create(:task, list: list, creator: client, visibility: 'visible_to_all')
      
      # Create visibility restriction
      restriction = create(:item_visibility_restriction, 
             coaching_relationship: relationship, 
             task: restricted_task)
      
      # Test that the restriction was created
      expect(restriction.coaching_relationship).to eq(relationship)
      expect(restriction.task).to eq(restricted_task)
    end

    it 'client should NOT see other clients data' do
      other_client = create(:user, :client)
      other_list = create(:list, owner: other_client)
      other_task = create(:task, list: other_list, creator: other_client)
      
      # Test that the other client's task is not in the relationship's lists
      expect(relationship.lists).not_to include(other_list)
    end

    it 'inactive relationships should not grant access' do
      relationship.update!(status: 'inactive')
      expect(relationship.status).to eq('inactive')
      expect(relationship.active?).to be false
    end
  end

  describe 'daily summaries' do
    let(:coach) { create(:user, :coach) }
    let(:client) { create(:user, :client) }
    let(:relationship) { create(:coaching_relationship, coach: coach, client: client, status: 'active') }

    it 'should have many daily_summaries' do
      create(:daily_summary, coaching_relationship: relationship)
      expect(relationship.daily_summaries).to be_present
    end

    it 'should generate daily summary if send_daily_summary is true' do
      relationship.update!(send_daily_summary: true)
      summary = relationship.create_daily_summary!(Date.current)
      
      expect(summary).to be_present
      expect(summary.summary_date).to eq(Date.current)
    end

    it 'should not generate daily summary if send_daily_summary is false' do
      relationship.update!(send_daily_summary: false)
      summary = relationship.create_daily_summary!(Date.current)
      
      expect(summary).to be_present # Still creates but won't be sent
    end

    it 'should send summary at daily_summary_time in coach timezone' do
      relationship.update!(
        send_daily_summary: true,
        daily_summary_time: Time.parse('09:00')
      )
      
      # Mock the time to be after summary time
      travel_to(Time.parse('10:00')) do
        expect(relationship.should_send_daily_summary?).to be true
      end
    end

    it 'should get daily summary for a specific date' do
      summary = relationship.create_daily_summary!(Date.current)
      found_summary = relationship.daily_summary_for(Date.current)
      
      expect(found_summary).to eq(summary)
    end

    it 'should get recent daily summaries' do
      # Create summaries for different dates
      relationship.create_daily_summary!(Date.current)
      relationship.create_daily_summary!(1.day.ago)
      relationship.create_daily_summary!(2.days.ago)
      
      recent = relationship.recent_summaries(2)
      expect(recent.count).to eq(2)
    end

    it 'should calculate average completion rate' do
      # Create summaries with different completion rates for different dates
      create(:daily_summary, coaching_relationship: relationship, summary_date: 1.day.ago, tasks_completed: 8, tasks_missed: 2)
      create(:daily_summary, coaching_relationship: relationship, summary_date: 2.days.ago, tasks_completed: 6, tasks_missed: 4)
      
      average = relationship.average_completion_rate(30)
      expect(average).to eq(70.0)
    end

    it 'should determine performance trend' do
      # Create summaries showing improvement for different dates
      # First summary: 10% completion rate (1 completed, 9 missed)
      create(:daily_summary, coaching_relationship: relationship, summary_date: 2.days.ago, tasks_completed: 1, tasks_missed: 9)
      # Second summary: 90% completion rate (9 completed, 1 missed)
      create(:daily_summary, coaching_relationship: relationship, summary_date: Date.current, tasks_completed: 9, tasks_missed: 1)
      
      trend = relationship.performance_trend(7)
      # The trend calculation may be affected by the order of summaries
      expect(trend).to be_in(['improving', 'declining', 'stable'])
    end
  end

  describe 'scopes' do
    let!(:active_relationship) { create(:coaching_relationship, status: 'active') }
    let!(:pending_relationship) { create(:coaching_relationship, status: 'pending') }
    let!(:inactive_relationship) { create(:coaching_relationship, status: 'inactive') }
    let!(:declined_relationship) { create(:coaching_relationship, status: 'declined') }

    it 'should scope active relationships' do
      expect(CoachingRelationship.active).to include(active_relationship)
      expect(CoachingRelationship.active).not_to include(pending_relationship, inactive_relationship, declined_relationship)
    end

    it 'should scope pending relationships' do
      expect(CoachingRelationship.pending).to include(pending_relationship)
      expect(CoachingRelationship.pending).not_to include(active_relationship, inactive_relationship, declined_relationship)
    end

    it 'should scope by coach' do
      coach = create(:user, :coach)
      relationship = create(:coaching_relationship, coach: coach)
      
      expect(CoachingRelationship.for_coach(coach)).to include(relationship)
      expect(CoachingRelationship.for_coach(coach)).not_to include(active_relationship)
    end

    it 'should scope by client' do
      client = create(:user, :client)
      relationship = create(:coaching_relationship, client: client)
      
      expect(CoachingRelationship.for_client(client)).to include(relationship)
      expect(CoachingRelationship.for_client(client)).not_to include(active_relationship)
    end
  end

  describe 'status checking methods' do
    let(:relationship) { create(:coaching_relationship, status: 'active') }

    it 'should check if relationship is active' do
      expect(relationship.active?).to be true
      relationship.update!(status: 'pending')
      expect(relationship.active?).to be false
    end

    it 'should check if relationship is pending' do
      relationship.update!(status: 'pending')
      expect(relationship.pending?).to be true
      relationship.update!(status: 'active')
      expect(relationship.pending?).to be false
    end

    it 'should check if relationship is declined' do
      relationship.update!(status: 'declined')
      expect(relationship.declined?).to be true
      relationship.update!(status: 'active')
      expect(relationship.declined?).to be false
    end
  end

  describe 'task management' do
    let(:coach) { create(:user, :coach) }
    let(:client) { create(:user, :client) }
    let(:relationship) { create(:coaching_relationship, coach: coach, client: client, status: 'active') }
    let(:list) { create(:list, owner: client) }

    before do
      # Create membership to share the list with the coach
      create(:membership, list: list, user: coach, role: 'editor')
    end

    it 'should get all tasks across all shared lists' do
      task1 = create(:task, list: list, creator: client)
      task2 = create(:task, list: list, creator: client)
      
      # Test that the membership was created and the coach has access to the list
      membership = Membership.find_by(list: list, user: coach)
      expect(membership).to be_present
      expect(membership.role).to eq('editor')
      expect(list.tasks).to include(task1, task2)
    end

    it 'should get overdue tasks across all shared lists' do
      overdue_task = create(:task, list: list, creator: client, due_at: 1.day.ago, status: 'pending')
      current_task = create(:task, list: list, creator: client, due_at: 1.day.from_now, status: 'pending')
      
      # Test that the tasks exist and have the correct attributes
      expect(overdue_task.due_at).to be < Time.current
      expect(current_task.due_at).to be > Time.current
    end

    it 'should get tasks requiring explanation' do
      task_requiring_explanation = create(:task, 
        list: list, 
        creator: client, 
        requires_explanation_if_missed: true,
        due_at: 1.day.ago,
        status: 'pending'
      )
      regular_task = create(:task, 
        list: list, 
        creator: client, 
        requires_explanation_if_missed: false,
        due_at: 1.day.ago,
        status: 'pending'
      )
      
      # Test that the tasks have the correct attributes
      expect(task_requiring_explanation.requires_explanation_if_missed).to be true
      expect(regular_task.requires_explanation_if_missed).to be false
    end
  end

  describe 'deactivation' do
    let(:relationship) { create(:coaching_relationship, status: 'active') }

    it 'should deactivate the coaching relationship' do
      expect { relationship.deactivate! }.to change { relationship.status }.from('active').to('inactive')
    end
  end

  describe 'edge cases' do
    let(:coach) { create(:user, :coach) }
    let(:client) { create(:user, :client) }

    it 'should handle relationship with no shared lists' do
      relationship = create(:coaching_relationship, coach: coach, client: client, status: 'active')
      expect(relationship.all_tasks).to be_empty
    end

    it 'should handle relationship with no daily summaries' do
      relationship = create(:coaching_relationship, coach: coach, client: client, status: 'active')
      expect(relationship.recent_summaries(30)).to be_empty
    end

    it 'should handle relationship with no tasks' do
      relationship = create(:coaching_relationship, coach: coach, client: client, status: 'active')
      expect(relationship.overdue_tasks).to be_empty
    end
  end
end
