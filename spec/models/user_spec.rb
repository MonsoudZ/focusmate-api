require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:password) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_length_of(:password).is_at_least(6) }
    
    it 'should validate role presence' do
      user = build(:user, role: nil)
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include("can't be blank")
    end
    
    it 'should validate role inclusion' do
      user = build(:user, role: 'invalid_role')
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include('is not included in the list')
    end
  end

  describe 'associations' do
    it { should have_many(:owned_lists).class_name('List').with_foreign_key('user_id') }
    it { should have_many(:created_tasks).class_name('Task').with_foreign_key('creator_id') }
    it { should have_many(:coaching_relationships_as_coach).class_name('CoachingRelationship').with_foreign_key('coach_id') }
    it { should have_many(:coaching_relationships_as_client).class_name('CoachingRelationship').with_foreign_key('client_id') }
    it { should have_many(:devices) }
    it { should have_many(:notification_logs) }
    it { should have_many(:saved_locations) }
    it { should have_many(:user_locations) }
  end

  describe 'authentication and security' do
    describe 'user creation' do
      it 'should create user with valid email/password' do
        user = build(:user, email: 'test@example.com', password: 'password123')
        expect(user).to be_valid
        expect(user.save).to be true
      end

      it 'should not create user with duplicate email' do
        create(:user, email: 'duplicate@example.com')
        user = build(:user, email: 'duplicate@example.com')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end

      it 'should generate JTI token on create' do
        user = create(:user)
        expect(user.jti).to be_present
        expect(user.jti).to be_a(String)
      end

      it 'should validate email format' do
        invalid_emails = ['invalid-email', 'test@', '@example.com']
        
        invalid_emails.each do |email|
          user = build(:user, email: email, password: 'password123', password_confirmation: 'password123')
          expect(user).not_to be_valid
          expect(user.errors[:email]).to include('is invalid')
        end
      end

      it 'should require password minimum 6 characters' do
        user = build(:user, password: '12345')
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
      end

      it 'should encrypt password' do
        user = create(:user, password: 'password123')
        expect(user.encrypted_password).to be_present
        expect(user.encrypted_password).not_to eq('password123')
        expect(user.valid_password?('password123')).to be true
      end

      it 'should identify coach vs client role correctly' do
        coach = create(:user, :coach)
        client = create(:user, :client)
        
        expect(coach.coach?).to be true
        expect(coach.client?).to be false
        expect(client.coach?).to be false
        expect(client.client?).to be true
      end
    end
  end

  describe 'relationships and associations' do
    let(:user) { create(:user) }

    it 'should have many owned_lists' do
      list1 = create(:list, owner: user)
      list2 = create(:list, owner: user)
      
      expect(user.owned_lists).to include(list1, list2)
      expect(user.owned_lists.count).to eq(2)
    end

    it 'should have many created_tasks' do
      list = create(:list, owner: user)
      task1 = create(:task, creator: user, list: list)
      task2 = create(:task, creator: user, list: list)
      
      expect(user.created_tasks).to include(task1, task2)
      expect(user.created_tasks.count).to eq(2)
    end

    it 'should have many coaching_relationships as coach' do
      client = create(:user, :client)
      relationship = create(:coaching_relationship, coach: user, client: client)
      
      expect(user.coaching_relationships_as_coach).to include(relationship)
    end

    it 'should have many coaching_relationships as client' do
      coach = create(:user, :coach)
      relationship = create(:coaching_relationship, coach: coach, client: user)
      
      expect(user.coaching_relationships_as_client).to include(relationship)
    end

    it 'should have many devices' do
      device1 = create(:device, user: user)
      device2 = create(:device, user: user)
      
      expect(user.devices).to include(device1, device2)
      expect(user.devices.count).to eq(2)
    end

    it 'should have many notification_logs' do
      log1 = create(:notification_log, user: user)
      log2 = create(:notification_log, user: user)
      
      expect(user.notification_logs).to include(log1, log2)
      expect(user.notification_logs.count).to eq(2)
    end

    it 'should have many saved_locations' do
      location1 = create(:saved_location, user: user)
      location2 = create(:saved_location, user: user)
      
      expect(user.saved_locations).to include(location1, location2)
      expect(user.saved_locations.count).to eq(2)
    end
  end

  describe 'location tracking' do
    let(:user) { create(:user) }

    it 'should update current location' do
      user.update_current_location(40.7128, -74.0060)
      
      expect(user.current_latitude).to eq(40.7128)
      expect(user.current_longitude).to eq(-74.0060)
    end

    it 'should track location history in user_locations' do
      user.update_current_location(40.7128, -74.0060)
      user.update_current_location(40.7589, -73.9851)
      
      expect(user.user_locations.count).to eq(2)
      expect(user.user_locations.first.latitude).to eq(40.7128)
      expect(user.user_locations.last.latitude).to eq(40.7589)
    end

    it 'should calculate distance to saved location' do
      saved_location = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060)
      user.update_current_location(40.7589, -73.9851)
      
      distance = user.distance_to_saved_location(saved_location)
      expect(distance).to be > 0
      expect(distance).to be < 10_000 # Should be less than 10 km (in meters)
    end

    it 'should know if user is at a saved location (within radius)' do
      saved_location = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060, radius_meters: 1000)
      user.update_current_location(40.7128, -74.0060) # Same location
      
      expect(user.at_saved_location?(saved_location)).to be true
    end

    it 'should not allow invalid coordinates (lat > 90 or < -90)' do
      expect { user.update_current_location(91.0, -74.0060) }.to raise_error(ArgumentError)
      expect { user.update_current_location(-91.0, -74.0060) }.to raise_error(ArgumentError)
    end

    it 'should not allow negative radius' do
      expect { 
        create(:saved_location, user: user, radius_meters: -100) 
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'business logic' do
    let(:user) { create(:user) }
    let(:list) { create(:list, owner: user) }

    it 'should get all overdue tasks for user' do
      overdue_task = create(:task, :overdue, creator: user, list: list)
      future_task = create(:task, creator: user, list: list, due_at: 1.day.from_now)
      
      overdue_tasks = user.overdue_tasks
      expect(overdue_tasks).to include(overdue_task)
      expect(overdue_tasks).not_to include(future_task)
    end

    it 'should get tasks requiring explanation' do
      task_requiring_explanation = create(:task, :requires_explanation, creator: user, list: list)
      regular_task = create(:task, creator: user, list: list)
      
      tasks_requiring_explanation = user.tasks_requiring_explanation
      expect(tasks_requiring_explanation).to include(task_requiring_explanation)
      expect(tasks_requiring_explanation).not_to include(regular_task)
    end

    it 'should get notification statistics (total, unread, delivered)' do
      create(:notification_log, user: user, delivered: true, metadata: { "read" => false })
      create(:notification_log, user: user, delivered: true, metadata: { "read" => true })
      create(:notification_log, user: user, delivered: false)
      
      stats = user.notification_stats
      expect(stats[:total]).to eq(3)
      expect(stats[:unread]).to eq(3) # All notifications are unread by default
      expect(stats[:delivered]).to eq(2)
    end

    it 'should validate timezone is valid IANA timezone' do
      valid_timezones = ['America/New_York', 'Europe/London', 'Asia/Tokyo', 'UTC']
      
      valid_timezones.each do |timezone|
        user = build(:user, timezone: timezone)
        expect(user).to be_valid
      end
      
      invalid_timezones = ['Invalid/Timezone', 'Not_A_Timezone']
      
      invalid_timezones.each do |timezone|
        user = build(:user, timezone: timezone)
        expect(user).not_to be_valid
        expect(user.errors[:timezone]).to include('is not a valid timezone')
      end
    end

    it 'should handle users in different timezones correctly' do
      user_ny = create(:user, timezone: 'America/New_York')
      user_london = create(:user, timezone: 'Europe/London')
      
      # Test that timezone is stored correctly
      expect(user_ny.timezone).to eq('America/New_York')
      expect(user_london.timezone).to eq('Europe/London')
    end
  end

  describe 'password confirmation' do
    it 'should require password confirmation to match' do
      user = build(:user, password: 'password123', password_confirmation: 'different_password')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe 'device management' do
    let(:user) { create(:user) }

    it 'should track device count' do
      create(:device, user: user)
      create(:device, user: user)
      
      expect(user.device_count).to eq(2)
      expect(user.has_devices?).to be true
    end

    it 'should know when user has no devices' do
      expect(user.device_count).to eq(0)
      expect(user.has_devices?).to be false
    end
  end
end
