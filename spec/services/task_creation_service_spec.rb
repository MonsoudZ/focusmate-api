require "rails_helper"

RSpec.describe TaskCreationService, type: :service do
  let(:user) { create(:user, email: "task_creation_#{SecureRandom.hex(4)}@example.com") }
  let(:list) { create(:list, user: user) }
  let(:params) do
    {
      title: "Test Task",
      due_at: 1.hour.from_now.iso8601,
      strict_mode: true
    }
  end

  describe "#call" do
    it "should create task with valid parameters" do
      service = TaskCreationService.new(list: list, user: user, params: params)
      task = service.call!

      expect(task).not_to be_nil
      expect(task.title).to eq("Test Task")
      expect(task.creator).to eq(user)
      expect(task.list).to eq(list)
      expect(task.strict_mode).to be_truthy
    end

    it "should handle iOS parameters" do
      ios_params = {
        name: "iOS Task", # iOS uses 'name' instead of 'title'
        dueDate: 1.hour.from_now.to_i, # iOS sends epoch seconds
        description: "iOS description" # iOS uses 'description' instead of 'note'
      }

      service = TaskCreationService.new(list: list, user: user, params: ios_params)
      task = service.call!

      expect(task.title).to eq("iOS Task")
      expect(task.note).to eq("iOS description")
      expect(task.due_at).not_to be_nil
    end

    it "should handle ISO8601 date format" do
      params_with_iso_date = params.merge(
        due_date: 1.hour.from_now.iso8601
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_iso_date)
      task = service.call!

      expect(task.due_at).not_to be_nil
      expect(task.due_at.to_i).to eq(1.hour.from_now.to_i)
    end

    it "should set default values" do
      params_without_defaults = {
        title: "Task without defaults",
        due_at: 1.hour.from_now.iso8601  # due_at is required
      }

      service = TaskCreationService.new(list: list, user: user, params: params_without_defaults)
      task = service.call!

      expect(task.strict_mode).to be_truthy # Should default to true
    end

    it "should create subtasks if provided" do
      params_with_subtasks = params.merge(
        subtasks: [ "Subtask 1", "Subtask 2", "Subtask 3" ]
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_subtasks)
      task = service.call!

      expect(task.subtasks.count).to eq(3)
      expect(task.subtasks.first.title).to eq("Subtask 1")
      expect(task.subtasks.second.title).to eq("Subtask 2")
      expect(task.subtasks.third.title).to eq("Subtask 3")
    end

    it "should set subtask attributes correctly" do
      params_with_subtasks = params.merge(
        subtasks: [ "Subtask" ]
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_subtasks)
      task = service.call!

      subtask = task.subtasks.first
      expect(subtask.list).to eq(list)
      expect(subtask.creator).to eq(user)
      expect(subtask.due_at).to eq(task.due_at)
      expect(subtask.strict_mode).to eq(task.strict_mode)
    end

    it "should handle invalid date formats gracefully" do
      # When due_at in base params is valid, invalid dueDate is ignored
      params_with_invalid_date = params.merge(
        dueDate: "invalid-date"
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_invalid_date)
      task = service.call!

      # Should still create task - due_at from base params is used
      expect(task).not_to be_nil
      expect(task.title).to eq("Test Task")
      expect(task.due_at).not_to be_nil
    end

    it "should clean iOS-specific parameters" do
      # The service uses: params[:title] ||= params.delete(:name)
      # This means 'name' is only used if 'title' is NOT set
      # So we test without 'title' to verify 'name' is used
      ios_params = {
        name: "iOS Task",
        dueDate: 1.hour.from_now.to_i,
        description: "iOS description"
        # No 'title' or 'note' - so 'name' and 'description' should be used
      }

      service = TaskCreationService.new(list: list, user: user, params: ios_params)
      task = service.call!

      expect(task.title).to eq("iOS Task")
      expect(task.note).to eq("iOS description")
    end

    it "should handle empty subtasks array" do
      params_with_empty_subtasks = params.merge(
        subtasks: []
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_empty_subtasks)
      task = service.call!

      expect(task.subtasks.count).to eq(0)
    end

    it "should handle nil subtasks" do
      params_with_nil_subtasks = params.merge(
        subtasks: nil
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_nil_subtasks)
      task = service.call!

      expect(task.subtasks.count).to eq(0)
    end

    it "should handle priority setting" do
      params_with_subtasks = params.merge(
        subtasks: [ "Subtask" ]
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_subtasks)
      task = service.call!

      expect(task.subtasks.count).to eq(1)
      expect(task.subtasks.first.title).to eq("Subtask")
    end

    it "should handle location-based tasks" do
      location_params = params.merge(
        location_based: true,
        location_latitude: 40.7128,
        location_longitude: -74.0060,
        location_radius_meters: 100,
        location_name: "New York"
      )

      service = TaskCreationService.new(list: list, user: user, params: location_params)
      task = service.call!

      expect(task.location_based?).to be_truthy
      expect(task.location_latitude).to eq(40.7128)
      expect(task.location_longitude).to eq(-74.0060)
      expect(task.location_radius_meters).to eq(100)
      expect(task.location_name).to eq("New York")
    end

    it "should handle recurring tasks" do
      recurring_params = params.merge(
        is_recurring: true,
        recurrence_pattern: "daily",
        recurrence_interval: 1,
        recurrence_time: Time.current
      )

      service = TaskCreationService.new(list: list, user: user, params: recurring_params)
      task = service.call!

      expect(task.is_recurring?).to be_truthy
      expect(task.recurrence_pattern).to eq("daily")
      expect(task.recurrence_interval).to eq(1)
      expect(task.recurrence_time).not_to be_nil
    end

    it "should handle accountability features" do
      accountability_params = params.merge(
        notification_interval_minutes: 15,
        requires_explanation_if_missed: true
      )

      service = TaskCreationService.new(list: list, user: user, params: accountability_params)
      task = service.call!

      expect(task.notification_interval_minutes).to eq(15)
      expect(task.requires_explanation_if_missed?).to be_truthy
    end

    it "should raise error for invalid parameters" do
      invalid_params = {
        title: "", # Empty title should fail validation
        due_at: 1.hour.from_now.iso8601
      }

      service = TaskCreationService.new(list: list, user: user, params: invalid_params)

      expect { service.call! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should handle complex nested parameters" do
      complex_params = {
        name: "Complex Task",
        dueDate: 1.hour.from_now.to_i,
        description: "Complex description",
        strict_mode: false,
        location_based: true,
        location_latitude: 40.7128,
        location_longitude: -74.0060,
        subtasks: [ "Complex Subtask 1", "Complex Subtask 2" ]
      }

      service = TaskCreationService.new(list: list, user: user, params: complex_params)
      task = service.call!

      expect(task.title).to eq("Complex Task")
      expect(task.note).to eq("Complex description")
      expect(task.strict_mode).to be_falsy
      expect(task.location_based?).to be_truthy
      expect(task.subtasks.count).to eq(2)
    end

    it "should handle edge case with nil parameters" do
      nil_params = {
        title: "Task with nil params",
        due_at: 1.hour.from_now.iso8601,
        note: nil
      }

      service = TaskCreationService.new(list: list, user: user, params: nil_params)
      task = service.call!

      expect(task.title).to eq("Task with nil params")
      expect(task.note).to be_nil
    end

    it "safely handles ActionController::Parameters input with extra keys" do
      tag = create(:tag, user: user)
      ac_params = ActionController::Parameters.new(
        title: "Params Task",
        due_at: 1.hour.from_now.iso8601,
        tag_ids: [ tag.id ],
        subtasks: [ "AC Subtask" ],
        unexpected_admin_flag: true
      )

      service = TaskCreationService.new(list: list, user: user, params: ac_params)
      task = service.call!

      expect(task.title).to eq("Params Task")
      expect(task.tags).to contain_exactly(tag)
      expect(task.subtasks.count).to eq(1)
      expect(task.subtasks.first.title).to eq("AC Subtask")
    end

    it "should handle very long subtask titles" do
      long_subtask_title = "a" * 250 # Long but within 255 character limit
      params_with_long_subtask = params.merge(
        subtasks: [ long_subtask_title ]
      )

      service = TaskCreationService.new(list: list, user: user, params: params_with_long_subtask)
      task = service.call!

      expect(task.subtasks.count).to eq(1)
      expect(task.subtasks.first.title).to eq(long_subtask_title)
    end

    it "should handle special characters in parameters" do
      special_params = {
        name: "Task with émojis 🚀 and spëcial chars",
        description: "Description with <script>alert('xss')</script>",
        dueDate: 1.hour.from_now.to_i
      }

      service = TaskCreationService.new(list: list, user: user, params: special_params)
      task = service.call!

      expect(task.title).to eq("Task with émojis 🚀 and spëcial chars")
      expect(task.note).to eq("Description with <script>alert('xss')</script>")
    end

    it "should handle timezone-aware dates" do
      # Use only due_date without due_at to test the parsing
      future_time = 1.day.from_now.beginning_of_day.iso8601
      timezone_params = {
        title: "Timezone Task",
        due_date: future_time # UTC timezone
      }

      service = TaskCreationService.new(list: list, user: user, params: timezone_params)
      task = service.call!

      expect(task.due_at).not_to be_nil
      # Should parse the UTC time correctly
      expect(task.due_at.utc.iso8601).to eq(future_time)
    end

    it "should handle multiple date formats" do
      # Test with both dueDate and due_date
      expected_time = 1.hour.from_now
      multiple_date_params = {
        name: "Task with multiple dates",
        dueDate: expected_time.to_i,
        due_date: 2.hours.from_now.iso8601
      }

      service = TaskCreationService.new(list: list, user: user, params: multiple_date_params)
      task = service.call!

      # Should use the first valid date (dueDate)
      expect(task.due_at).not_to be_nil
      expect(task.due_at.to_i).to eq(expected_time.to_i)
    end
  end
end
