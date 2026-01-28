# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushNotifications::Sender do
  let(:user) { create(:user) }

  before do
    # Reset memoized connection between tests
    described_class.instance_variable_set(:@connection, nil)
    described_class.instance_variable_set(:@temp_key_file, nil)
  end

  describe ".send_to_user" do
    it "does nothing when user has no iOS devices" do
      expect(described_class).not_to receive(:send_to_device)
      described_class.send_to_user(user: user, title: "Test", body: "Body")
    end

    it "sends to each active iOS device" do
      device1 = create(:device, user: user, platform: "ios")
      device2 = create(:device, user: user, platform: "ios")
      _android = create(:device, :android, user: user)

      allow(described_class).to receive(:send_to_device)

      described_class.send_to_user(user: user, title: "Test", body: "Body")

      expect(described_class).to have_received(:send_to_device).twice
    end

    it "skips inactive devices" do
      create(:device, user: user, platform: "ios", active: false)

      expect(described_class).not_to receive(:send_to_device)
      described_class.send_to_user(user: user, title: "Test", body: "Body")
    end
  end

  describe ".send_to_device" do
    let(:device) { create(:device, user: user, platform: "ios") }
    let(:mock_connection) { instance_double("Apnotic::Connection") }

    before do
      described_class.instance_variable_set(:@connection, mock_connection)
      allow(mock_connection).to receive(:push_async)
      allow(ENV).to receive(:fetch).with("APNS_BUNDLE_ID").and_return("com.focusmate.app")
    end

    it "builds and sends a notification" do
      described_class.send_to_device(
        device: device,
        title: "Hello",
        body: "World"
      )

      expect(mock_connection).to have_received(:push_async).with(an_instance_of(Apnotic::Notification))
    end

    it "skips devices without apns_token" do
      device.update_column(:apns_token, nil)

      described_class.send_to_device(
        device: device,
        title: "Hello",
        body: "World"
      )

      expect(mock_connection).not_to have_received(:push_async)
    end

    it "logs errors and does not raise" do
      allow(mock_connection).to receive(:push_async).and_raise(StandardError.new("connection lost"))

      expect(Rails.logger).to receive(:error).with(/Push failed for device #{device.id}/)

      expect {
        described_class.send_to_device(device: device, title: "Hello", body: "World")
      }.not_to raise_error
    end

    it "includes custom data payload" do
      described_class.send_to_device(
        device: device,
        title: "Hello",
        body: "World",
        data: { type: "reminder", task_id: 123 }
      )

      expect(mock_connection).to have_received(:push_async) do |notification|
        expect(notification.custom_payload).to eq({ type: "reminder", task_id: 123 })
      end
    end
  end

  describe ".send_nudge" do
    let(:from_user) { create(:user, name: "Alice") }
    let(:to_user) { create(:user) }
    let(:task) { create(:task, list: create(:list, user: to_user), creator: to_user, title: "Do homework") }

    it "sends a nudge notification with correct content" do
      allow(described_class).to receive(:send_to_user)

      described_class.send_nudge(from_user: from_user, to_user: to_user, task: task)

      expect(described_class).to have_received(:send_to_user).with(
        user: to_user,
        title: "Nudge from Alice",
        body: "Alice is reminding you about: Do homework",
        data: hash_including(
          type: "nudge",
          task_id: task.id,
          list_id: task.list_id,
          from_user_id: from_user.id
        )
      )
    end
  end
end
