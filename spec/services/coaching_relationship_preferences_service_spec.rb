require 'rails_helper'

RSpec.describe CoachingRelationshipPreferencesService do
  let(:coach) { create(:user, email: 'coach@example.com') }
  let(:client) { create(:user, email: 'client@example.com') }
  let(:relationship) do
    create(:coaching_relationship,
           coach: coach,
           client: client,
           status: 'active')
  end

  describe '#update!' do
    context 'authorization' do
      it 'allows coach to update preferences' do
        params = { notify_on_completion: true }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'raises UnauthorizedError when client tries to update preferences' do
        params = { notify_on_completion: true }
        service = described_class.new(relationship: relationship, current_user: client, params: params)

        expect {
          service.update!
        }.to raise_error(CoachingRelationshipPreferencesService::UnauthorizedError, 'Only coaches can update preferences')
      end

      it 'raises UnauthorizedError when third party tries to update preferences' do
        other_user = create(:user)
        params = { notify_on_completion: true }
        service = described_class.new(relationship: relationship, current_user: other_user, params: params)

        expect {
          service.update!
        }.to raise_error(CoachingRelationshipPreferencesService::UnauthorizedError, 'Only coaches can update preferences')
      end
    end

    context 'boolean field updates' do
      it 'updates notify_on_completion with boolean true' do
        params = { notify_on_completion: true }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'updates notify_on_completion with boolean false' do
        params = { notify_on_completion: false }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be false
      end

      it 'updates notify_on_missed_deadline' do
        params = { notify_on_missed_deadline: true }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_missed_deadline).to be true
      end

      it 'updates send_daily_summary' do
        params = { send_daily_summary: true }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.send_daily_summary).to be true
      end

      it 'updates multiple boolean fields at once' do
        params = {
          notify_on_completion: true,
          notify_on_missed_deadline: false,
          send_daily_summary: true
        }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
        expect(result.notify_on_missed_deadline).to be false
        expect(result.send_daily_summary).to be true
      end
    end

    context 'boolean string casting' do
      it 'casts "true" string to true' do
        params = { notify_on_completion: "true" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'casts "false" string to false' do
        params = { notify_on_completion: "false" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be false
      end

      it 'casts "1" string to true' do
        params = { notify_on_completion: "1" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'casts "0" string to false' do
        params = { notify_on_completion: "0" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be false
      end

      it 'casts "yes" string to true' do
        params = { notify_on_completion: "yes" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'casts "no" string to false' do
        params = { notify_on_completion: "no" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be false
      end

      it 'casts "on" string to true' do
        params = { notify_on_completion: "on" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'casts "off" string to false' do
        params = { notify_on_completion: "off" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be false
      end

      it 'handles case-insensitive boolean strings' do
        params = { notify_on_completion: "TRUE" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'handles boolean strings with whitespace' do
        params = { notify_on_completion: "  true  " }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
      end

      it 'casts empty string to false' do
        params = { notify_on_completion: "" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be false
      end
    end

    context 'time parsing' do
      it 'parses valid HH:MM time format (09:30)' do
        params = { daily_summary_time: "09:30" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time).to be_present
        expect(result.daily_summary_time.hour).to eq(9)
        expect(result.daily_summary_time.min).to eq(30)
      end

      it 'parses valid HH:MM time format (14:45)' do
        params = { daily_summary_time: "14:45" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time.hour).to eq(14)
        expect(result.daily_summary_time.min).to eq(45)
      end

      it 'parses valid HH:MM time format with single digit hour (8:30)' do
        params = { daily_summary_time: "8:30" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time.hour).to eq(8)
        expect(result.daily_summary_time.min).to eq(30)
      end

      it 'parses midnight (00:00)' do
        params = { daily_summary_time: "00:00" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time.hour).to eq(0)
        expect(result.daily_summary_time.min).to eq(0)
      end

      it 'parses late evening (23:59)' do
        params = { daily_summary_time: "23:59" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time.hour).to eq(23)
        expect(result.daily_summary_time.min).to eq(59)
      end

      it 'raises ValidationError for invalid time format (25:00)' do
        params = { daily_summary_time: "25:00" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          service.update!
        }.to raise_error(CoachingRelationshipPreferencesService::ValidationError, 'Invalid time format')
      end

      it 'raises ValidationError for invalid time format (12:60)' do
        params = { daily_summary_time: "12:60" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          service.update!
        }.to raise_error(CoachingRelationshipPreferencesService::ValidationError, 'Invalid time format')
      end

      it 'raises ValidationError for invalid time format (abc)' do
        params = { daily_summary_time: "abc" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          service.update!
        }.to raise_error(CoachingRelationshipPreferencesService::ValidationError, 'Invalid time format')
      end

      it 'raises ValidationError for invalid time format (12:30:45)' do
        params = { daily_summary_time: "12:30:45" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          service.update!
        }.to raise_error(CoachingRelationshipPreferencesService::ValidationError, 'Invalid time format')
      end

      it 'allows nil time' do
        relationship.update!(daily_summary_time: Time.zone.parse("10:00"))
        params = { daily_summary_time: nil }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time).to be_nil
      end

      it 'allows blank string time' do
        relationship.update!(daily_summary_time: Time.zone.parse("10:00"))
        params = { daily_summary_time: "" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.daily_summary_time).to be_nil
      end
    end

    context 'timezone parameter' do
      it 'accepts timezone parameter but does not store it' do
        params = {
          notify_on_completion: true,
          timezone: "America/New_York"
        }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          result = service.update!
          expect(result.notify_on_completion).to be true
        }.not_to raise_error
      end

      it 'does not fail when only timezone is provided' do
        params = { timezone: "America/Los_Angeles" }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          service.update!
        }.not_to raise_error
      end
    end

    context 'combined updates' do
      it 'updates all preference fields together' do
        params = {
          notify_on_completion: true,
          notify_on_missed_deadline: false,
          send_daily_summary: true,
          daily_summary_time: "10:00",
          timezone: "America/Chicago"
        }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        result = service.update!

        expect(result.notify_on_completion).to be true
        expect(result.notify_on_missed_deadline).to be false
        expect(result.send_daily_summary).to be true
        expect(result.daily_summary_time.hour).to eq(10)
        expect(result.daily_summary_time.min).to eq(0)
      end
    end

    context 'persistence' do
      it 'persists changes to database' do
        params = { notify_on_completion: true }
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        service.update!

        relationship.reload
        expect(relationship.notify_on_completion).to be true
      end
    end

    context 'empty params' do
      it 'handles empty params without error' do
        params = {}
        service = described_class.new(relationship: relationship, current_user: coach, params: params)

        expect {
          result = service.update!
          expect(result).to eq(relationship)
        }.not_to raise_error
      end
    end
  end

  describe 'UnauthorizedError' do
    it 'is a StandardError' do
      error = CoachingRelationshipPreferencesService::UnauthorizedError.new('Unauthorized')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Unauthorized')
    end
  end

  describe 'ValidationError' do
    it 'is a StandardError' do
      error = CoachingRelationshipPreferencesService::ValidationError.new('Validation failed')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Validation failed')
    end
  end
end
