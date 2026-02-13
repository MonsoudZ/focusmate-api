# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushNotifications::Sender do
  let(:user) { create(:user) }

  before do
    # Reset memoized connection between tests (set directly to avoid calling close on stale mocks)
    described_class.instance_variable_set(:@connection, nil)
    described_class.instance_variable_set(:@temp_key_file, nil)
  end

  describe ".reset_connection!" do
    it "closes memoized resources and clears references" do
      connection = instance_double("Apnotic::Connection", close: true)
      temp_key_file = Tempfile.new("apns-test")
      described_class.instance_variable_set(:@connection, connection)
      described_class.instance_variable_set(:@temp_key_file, temp_key_file)

      described_class.reset_connection!

      expect(connection).to have_received(:close)
      expect(described_class.instance_variable_get(:@connection)).to be_nil
      expect(described_class.instance_variable_get(:@temp_key_file)).to be_nil
    end

    it "continues cleanup when connection close fails" do
      connection = instance_double("Apnotic::Connection")
      allow(connection).to receive(:close).and_raise(StandardError.new("close failed"))
      temp_key_file = Tempfile.new("apns-test")
      allow(Rails.logger).to receive(:warn)

      described_class.instance_variable_set(:@connection, connection)
      described_class.instance_variable_set(:@temp_key_file, temp_key_file)

      expect { described_class.reset_connection! }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/APNS connection close failed: close failed/)
      expect(described_class.instance_variable_get(:@connection)).to be_nil
      expect(described_class.instance_variable_get(:@temp_key_file)).to be_nil
    end

    it "logs temp-key cleanup failures and still clears memoized file" do
      temp_key_file = instance_double(Tempfile, closed?: true)
      allow(temp_key_file).to receive(:unlink).and_raise(StandardError.new("unlink failed"))
      allow(Rails.logger).to receive(:warn)

      described_class.instance_variable_set(:@temp_key_file, temp_key_file)

      expect { described_class.reset_connection! }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/APNS temp key cleanup failed: unlink failed/)
      expect(described_class.instance_variable_get(:@temp_key_file)).to be_nil
    end
  end

  describe ".send_to_user" do
    it "does nothing when user has no iOS devices" do
      expect(described_class).not_to receive(:send_to_device)
      expect(described_class.send_to_user(user: user, title: "Test", body: "Body")).to be(false)
    end

    it "sends to each active iOS device" do
      device1 = create(:device, user: user, platform: "ios")
      device2 = create(:device, user: user, platform: "ios")
      _android = create(:device, :android, user: user)

      allow(described_class).to receive(:send_to_device)

      described_class.send_to_user(user: user, title: "Test", body: "Body")

      expect(described_class).to have_received(:send_to_device).twice
    end

    it "returns true when at least one device receives push" do
      create(:device, user: user, platform: "ios")
      allow(described_class).to receive(:send_to_device).and_return(true)

      expect(described_class.send_to_user(user: user, title: "Test", body: "Body")).to be(true)
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

    let(:mock_push) { double("Apnotic::Push", on: nil) }

    before do
      described_class.instance_variable_set(:@connection, mock_connection)
      allow(mock_connection).to receive(:push_async).and_return(mock_push)
      allow(ENV).to receive(:fetch).with("APNS_BUNDLE_ID").and_return("com.focusmate.app")
    end

    it "builds and sends a notification" do
      result = described_class.send_to_device(
        device: device,
        title: "Hello",
        body: "World"
      )

      expect(result).to be(true)
      expect(mock_connection).to have_received(:push_async).with(an_instance_of(Apnotic::Notification))
    end

    it "skips devices without apns_token" do
      device.update_column(:apns_token, nil)

      result = described_class.send_to_device(
        device: device,
        title: "Hello",
        body: "World"
      )

      expect(result).to be(false)
      expect(mock_connection).not_to have_received(:push_async)
    end

    it "logs errors and does not raise" do
      allow(mock_connection).to receive(:push_async).and_raise(StandardError.new("something went wrong"))
      allow(mock_connection).to receive(:close)

      expect(Rails.logger).to receive(:error).with(/Push failed for device #{device.id}/)

      expect {
        expect(described_class.send_to_device(device: device, title: "Hello", body: "World")).to be(false)
      }.not_to raise_error
    end

    it "resets connection on connection-related errors" do
      allow(mock_connection).to receive(:push_async).and_raise(StandardError.new("connection closed"))
      allow(mock_connection).to receive(:close)
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)

      described_class.send_to_device(device: device, title: "Hello", body: "World")

      expect(Rails.logger).to have_received(:warn).with(/APNS connection error detected/)
      expect(mock_connection).to have_received(:close)
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

  describe ".send_list_joined" do
    let(:owner) { create(:user) }
    let(:new_member) { create(:user, name: "Bob") }
    let(:list) { create(:list, user: owner, name: "My List") }

    it "sends notification to list owner with correct content" do
      allow(described_class).to receive(:send_to_user)

      described_class.send_list_joined(to_user: owner, new_member: new_member, list: list)

      expect(described_class).to have_received(:send_to_user).with(
        user: owner,
        title: "Bob joined your list",
        body: "Bob is now a member of \"My List\"",
        data: hash_including(
          type: "list_joined",
          list_id: list.id,
          user_id: new_member.id
        )
      )
    end
  end

  describe ".send_task_assigned" do
    let(:assignee) { create(:user) }
    let(:assigner) { create(:user, name: "Alice") }
    let(:list) { create(:list, user: assigner) }
    let(:task) { create(:task, list: list, creator: assigner, title: "Important task") }

    it "sends notification to assignee with correct content" do
      allow(described_class).to receive(:send_to_user)

      described_class.send_task_assigned(to_user: assignee, task: task, assigned_by: assigner)

      expect(described_class).to have_received(:send_to_user).with(
        user: assignee,
        title: "New task assigned to you",
        body: "Alice assigned you: Important task",
        data: hash_including(
          type: "task_assigned",
          task_id: task.id,
          list_id: task.list_id,
          assigned_by_id: assigner.id
        )
      )
    end
  end

  describe ".send_task_reminder" do
    let(:user) { create(:user) }
    let(:list) { create(:list, user: user) }
    let(:task) { create(:task, list: list, creator: user, title: "Reminder task") }

    it "sends reminder notification with correct content" do
      allow(described_class).to receive(:send_to_user)

      described_class.send_task_reminder(to_user: user, task: task)

      expect(described_class).to have_received(:send_to_user).with(
        user: user,
        title: "Task due soon",
        body: "Reminder task",
        data: hash_including(
          type: "task_reminder",
          task_id: task.id,
          list_id: task.list_id
        )
      )
    end
  end
end
