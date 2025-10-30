require 'rails_helper'

RSpec.describe UserPreferencesService do
  let(:user) { create(:user) }

  describe '#update!' do
    context 'with valid preferences' do
      it 'updates user preferences with hash' do
        preferences = { theme: 'dark', notifications: true }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences).to eq({ 'theme' => 'dark', 'notifications' => true })
      end

      it 'updates user preferences with ActionController::Parameters' do
        preferences = ActionController::Parameters.new({ theme: 'light', language: 'en' })
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['theme']).to eq('light')
        expect(result.preferences['language']).to eq('en')
      end

      it 'handles empty hash' do
        preferences = {}
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences).to eq({})
      end

      it 'overwrites existing preferences' do
        user.update!(preferences: { old_key: 'old_value' })
        preferences = { new_key: 'new_value' }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences).to eq({ 'new_key' => 'new_value' })
      end
    end

    context 'with nested preferences' do
      it 'handles nested hash structures' do
        preferences = {
          ui: {
            theme: 'dark',
            font_size: 14
          },
          notifications: {
            email: true,
            push: false
          }
        }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['ui']['theme']).to eq('dark')
        expect(result.preferences['ui']['font_size']).to eq(14)
        expect(result.preferences['notifications']['email']).to be true
        expect(result.preferences['notifications']['push']).to be false
      end

      it 'handles deeply nested structures' do
        preferences = {
          level1: {
            level2: {
              level3: {
                value: 'deep'
              }
            }
          }
        }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['level1']['level2']['level3']['value']).to eq('deep')
      end
    end

    context 'with array values' do
      it 'handles arrays of strings' do
        preferences = { tags: ['work', 'personal', 'urgent'] }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['tags']).to eq(['work', 'personal', 'urgent'])
      end

      it 'handles arrays of numbers' do
        preferences = { numbers: [1, 2, 3, 4, 5] }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['numbers']).to eq([1, 2, 3, 4, 5])
      end

      it 'handles arrays of mixed types' do
        preferences = { mixed: ['string', 123, true, nil] }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['mixed']).to eq(['string', 123, true, nil])
      end

      it 'handles nested arrays' do
        preferences = { nested_array: [[1, 2], [3, 4]] }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['nested_array']).to eq([[1, 2], [3, 4]])
      end
    end

    context 'with different data types' do
      it 'preserves string values' do
        preferences = { name: 'John Doe' }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['name']).to eq('John Doe')
      end

      it 'preserves numeric values' do
        preferences = { age: 30, score: 95.5 }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['age']).to eq(30)
        expect(result.preferences['score']).to eq(95.5)
      end

      it 'preserves boolean values' do
        preferences = { enabled: true, disabled: false }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['enabled']).to be true
        expect(result.preferences['disabled']).to be false
      end

      it 'preserves nil values' do
        preferences = { nullable: nil }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['nullable']).to be_nil
      end
    end

    context 'string sanitization' do
      it 'strips whitespace from strings' do
        preferences = { name: '  John Doe  ' }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['name']).to eq('John Doe')
      end

      it 'limits string length to 5000 characters' do
        long_string = 'a' * 6000
        preferences = { text: long_string }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['text'].length).to eq(5000)
        expect(result.preferences['text']).to eq('a' * 5000)
      end

      it 'does not truncate strings under 5000 characters' do
        string = 'a' * 4999
        preferences = { text: string }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['text'].length).to eq(4999)
      end

      it 'handles empty strings' do
        preferences = { empty: '' }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['empty']).to eq('')
      end
    end

    context 'recursive sanitization' do
      it 'sanitizes nested strings' do
        preferences = {
          outer: {
            inner: '  needs trimming  '
          }
        }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['outer']['inner']).to eq('needs trimming')
      end

      it 'sanitizes strings in arrays' do
        preferences = { items: ['  item1  ', '  item2  '] }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['items']).to eq(['item1', 'item2'])
      end

      it 'truncates long strings in nested structures' do
        long_string = 'a' * 6000
        preferences = {
          nested: {
            array: [long_string, 'short']
          }
        }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['nested']['array'][0].length).to eq(5000)
        expect(result.preferences['nested']['array'][1]).to eq('short')
      end
    end

    context 'with ActionController::Parameters' do
      it 'converts ActionController::Parameters to hash' do
        params = ActionController::Parameters.new({
          settings: ActionController::Parameters.new({
            option1: 'value1',
            option2: 'value2'
          })
        })
        service = described_class.new(user: user, preferences: params)

        result = service.update!

        expect(result.preferences['settings']).to be_a(Hash)
        expect(result.preferences['settings']['option1']).to eq('value1')
      end

      it 'handles deeply nested ActionController::Parameters' do
        params = ActionController::Parameters.new({
          level1: ActionController::Parameters.new({
            level2: ActionController::Parameters.new({
              value: 'deep_value'
            })
          })
        })
        service = described_class.new(user: user, preferences: params)

        result = service.update!

        expect(result.preferences['level1']['level2']['value']).to eq('deep_value')
      end
    end

    context 'with special characters' do
      it 'handles unicode characters' do
        preferences = { text: '你好世界 🌍' }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['text']).to eq('你好世界 🌍')
      end

      it 'handles special symbols' do
        preferences = { symbols: '!@#$%^&*()_+-=[]{}|;:,.<>?' }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['symbols']).to eq('!@#$%^&*()_+-=[]{}|;:,.<>?')
      end

      it 'handles newlines and tabs' do
        preferences = { text: "line1\nline2\tindented" }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['text']).to eq("line1\nline2\tindented")
      end
    end

    context 'with invalid preferences' do
      it 'raises ValidationError when preferences is not a hash' do
        service = described_class.new(user: user, preferences: 'string')

        expect {
          service.update!
        }.to raise_error(UserPreferencesService::ValidationError, 'Preferences must be a valid object')
      end

      it 'raises ValidationError when preferences is an array' do
        service = described_class.new(user: user, preferences: [1, 2, 3])

        expect {
          service.update!
        }.to raise_error(UserPreferencesService::ValidationError, 'Preferences must be a valid object')
      end

      it 'raises ValidationError when preferences is a number' do
        service = described_class.new(user: user, preferences: 123)

        expect {
          service.update!
        }.to raise_error(UserPreferencesService::ValidationError, 'Preferences must be a valid object')
      end

      it 'raises ValidationError when preferences is nil' do
        service = described_class.new(user: user, preferences: nil)

        expect {
          service.update!
        }.to raise_error(UserPreferencesService::ValidationError, 'Preferences must be a valid object')
      end
    end

    context 'error handling' do
      it 'raises ValidationError when user update fails' do
        preferences = { key: 'value' }
        service = described_class.new(user: user, preferences: preferences)

        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        expect {
          service.update!
        }.to raise_error(UserPreferencesService::ValidationError, 'Failed to update preferences')
      end

      it 'logs error when update fails' do
        preferences = { key: 'value' }
        service = described_class.new(user: user, preferences: preferences)

        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])
        allow(Rails.logger).to receive(:error)

        begin
          service.update!
        rescue UserPreferencesService::ValidationError
          # Expected error
        end

        expect(Rails.logger).to have_received(:error).with(/Preferences update failed/)
      end

      it 'includes error details in ValidationError' do
        preferences = { key: 'value' }
        service = described_class.new(user: user, preferences: preferences)

        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error 1', 'Error 2'])

        expect {
          service.update!
        }.to raise_error(UserPreferencesService::ValidationError) do |error|
          expect(error.details).to eq(['Error 1', 'Error 2'])
        end
      end
    end

    context 'persistence' do
      it 'persists preferences to database' do
        preferences = { theme: 'dark', language: 'en' }
        service = described_class.new(user: user, preferences: preferences)

        service.update!

        persisted_user = User.find(user.id)
        expect(persisted_user.preferences['theme']).to eq('dark')
        expect(persisted_user.preferences['language']).to eq('en')
      end
    end

    context 'with complex real-world preferences' do
      it 'handles typical user preferences structure' do
        preferences = {
          theme: 'dark',
          language: 'en',
          timezone: 'America/New_York',
          notifications: {
            email: true,
            push: false,
            sms: true
          },
          ui: {
            sidebar_collapsed: false,
            show_completed_tasks: true,
            items_per_page: 25
          },
          privacy: {
            profile_visible: true,
            show_email: false
          }
        }
        service = described_class.new(user: user, preferences: preferences)

        result = service.update!

        expect(result.preferences['theme']).to eq('dark')
        expect(result.preferences['notifications']['email']).to be true
        expect(result.preferences['ui']['items_per_page']).to eq(25)
        expect(result.preferences['privacy']['show_email']).to be false
      end
    end
  end

  describe 'ValidationError' do
    it 'is a StandardError' do
      error = UserPreferencesService::ValidationError.new('Test error')

      expect(error).to be_a(StandardError)
      expect(error.message).to eq('Test error')
    end

    it 'stores error details' do
      error = UserPreferencesService::ValidationError.new('Test error', ['Detail 1', 'Detail 2'])

      expect(error.details).to eq(['Detail 1', 'Detail 2'])
    end

    it 'defaults to empty array for details' do
      error = UserPreferencesService::ValidationError.new('Test error')

      expect(error.details).to eq([])
    end
  end
end
