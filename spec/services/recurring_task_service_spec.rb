# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringTaskService do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:service) { described_class.new(user) }

  describe "#create_recurring_task" do
    let(:params) do
      {
        title: "Daily standup",
        note: "Team sync",
        due_at: Time.zone.parse("2026-02-01 09:00:00")
      }
    end
    let(:recurrence_params) do
      { pattern: "daily", interval: 1 }
    end

    it "creates a template and first instance" do
      result = service.create_recurring_task(
        list: list,
        params: params,
        recurrence_params: recurrence_params
      )

      expect(result[:template]).to be_persisted
      expect(result[:template].is_template).to be true
      expect(result[:template].template_type).to eq("recurring")
      expect(result[:template].is_recurring).to be true

      expect(result[:instance]).to be_persisted
      expect(result[:instance].is_template).to be false
      expect(result[:instance].template_id).to eq(result[:template].id)
      expect(result[:instance].instance_number).to eq(1)
    end

    it "sets recurrence fields on the template" do
      result = service.create_recurring_task(
        list: list,
        params: params,
        recurrence_params: { pattern: "weekly", interval: 2, days: [ 1, 3, 5 ] }
      )

      template = result[:template]
      expect(template.recurrence_pattern).to eq("weekly")
      expect(template.recurrence_interval).to eq(2)
      expect(template.recurrence_days).to eq([ 1, 3, 5 ])
    end

    it "copies task attributes to instance" do
      result = service.create_recurring_task(
        list: list,
        params: params.merge(starred: true),
        recurrence_params: recurrence_params
      )

      instance = result[:instance]
      expect(instance.title).to eq("Daily standup")
      expect(instance.note).to eq("Team sync")
      expect(instance.starred).to be true
      expect(instance.list).to eq(list)
      expect(instance.creator).to eq(user)
    end

    it "wraps creation in a transaction" do
      allow_any_instance_of(ActiveRecord::Associations::CollectionProxy)
        .to receive(:create!).and_call_original

      # Force instance creation to fail
      allow_any_instance_of(Task).to receive(:instances).and_raise(ActiveRecord::RecordInvalid)

      expect {
        service.create_recurring_task(
          list: list,
          params: params,
          recurrence_params: recurrence_params
        )
      }.to raise_error(ActiveRecord::RecordInvalid)

      # Template should not persist due to transaction rollback
      expect(Task.where(is_template: true, title: "Daily standup").count).to eq(0)
    end

    it "respects recurrence_end_date" do
      result = service.create_recurring_task(
        list: list,
        params: params,
        recurrence_params: recurrence_params.merge(end_date: Date.new(2026, 3, 1))
      )

      expect(result[:template].recurrence_end_date.to_date).to eq(Date.new(2026, 3, 1))
    end

    it "respects recurrence_count" do
      result = service.create_recurring_task(
        list: list,
        params: params,
        recurrence_params: recurrence_params.merge(count: 10)
      )

      expect(result[:template].recurrence_count).to eq(10)
    end
  end

  describe "#generate_next_instance" do
    let(:result) do
      service.create_recurring_task(
        list: list,
        params: { title: "Recurring", due_at: Time.zone.parse("2026-02-01 09:00:00") },
        recurrence_params: { pattern: "daily", interval: 1 }
      )
    end

    it "creates the next instance from a completed one" do
      instance = result[:instance]
      next_instance = service.generate_next_instance(instance)

      expect(next_instance).to be_persisted
      expect(next_instance.instance_number).to eq(2)
      expect(next_instance.due_at.to_date).to eq(Date.new(2026, 2, 2))
    end

    it "returns nil for non-recurring tasks" do
      task = create(:task, list: list, creator: user)
      expect(service.generate_next_instance(task)).to be_nil
    end

    it "returns nil when recurrence count is reached" do
      template = result[:template]
      template.update!(recurrence_count: 1)

      instance = result[:instance]
      instance.update!(instance_number: 1)

      expect(service.generate_next_instance(instance)).to be_nil
    end

    it "returns nil when recurrence end date is passed" do
      template = result[:template]
      template.update!(recurrence_end_date: Date.new(2026, 2, 1))

      instance = result[:instance]

      travel_to(Date.new(2026, 2, 2)) do
        expect(service.generate_next_instance(instance)).to be_nil
      end
    end

    context "with weekly recurrence" do
      let(:weekly_result) do
        service.create_recurring_task(
          list: list,
          params: { title: "Weekly", due_at: Time.zone.parse("2026-02-02 10:00:00") },
          recurrence_params: { pattern: "weekly", interval: 1, days: [ 1 ] } # Monday
        )
      end

      it "advances to the next matching weekday" do
        instance = weekly_result[:instance]
        next_instance = service.generate_next_instance(instance)

        expect(next_instance).to be_persisted
        expect(next_instance.due_at.wday).to eq(1) # Monday
      end
    end

    context "with monthly recurrence" do
      let(:monthly_result) do
        service.create_recurring_task(
          list: list,
          params: { title: "Monthly", due_at: Time.zone.parse("2026-02-01 10:00:00") },
          recurrence_params: { pattern: "monthly", interval: 1 }
        )
      end

      it "advances by one month" do
        instance = monthly_result[:instance]
        next_instance = service.generate_next_instance(instance)

        expect(next_instance.due_at.to_date).to eq(Date.new(2026, 3, 1))
      end
    end

    context "with yearly recurrence" do
      let(:yearly_result) do
        service.create_recurring_task(
          list: list,
          params: { title: "Yearly", due_at: Time.zone.parse("2026-02-01 10:00:00") },
          recurrence_params: { pattern: "yearly", interval: 1 }
        )
      end

      it "advances by one year" do
        instance = yearly_result[:instance]
        next_instance = service.generate_next_instance(instance)

        expect(next_instance.due_at.to_date).to eq(Date.new(2027, 2, 1))
      end
    end

    context "with unknown recurrence pattern" do
      it "returns nil for unknown patterns" do
        result = service.create_recurring_task(
          list: list,
          params: { title: "Unknown", due_at: Time.zone.parse("2026-02-01 10:00:00") },
          recurrence_params: { pattern: "daily", interval: 1 }
        )

        # Manually set an invalid pattern to test else branch
        result[:template].update_column(:recurrence_pattern, "unknown_pattern")

        instance = result[:instance]
        expect(service.generate_next_instance(instance)).to be_nil
      end
    end

    context "when instance has nil due_at" do
      it "returns nil for next instance" do
        result = service.create_recurring_task(
          list: list,
          params: { title: "NoDue", due_at: Time.zone.parse("2026-02-01 10:00:00") },
          recurrence_params: { pattern: "daily", interval: 1 }
        )

        instance = result[:instance]
        instance.update_column(:due_at, nil)

        expect(service.generate_next_instance(instance.reload)).to be_nil
      end
    end

    context "when template is not a recurring template" do
      it "returns nil if template is nil" do
        task = create(:task, list: list, creator: user, template_id: nil)
        expect(service.generate_next_instance(task)).to be_nil
      end

      it "returns nil if template is not a template" do
        non_template = create(:task, list: list, creator: user, is_template: false)
        task = create(:task, list: list, creator: user)
        task.update_column(:template_id, non_template.id)

        expect(service.generate_next_instance(task.reload)).to be_nil
      end

      it "returns nil if template type is not recurring" do
        template = create(:task, list: list, creator: user, is_template: true, template_type: "other")
        task = create(:task, list: list, creator: user)
        task.update_column(:template_id, template.id)

        expect(service.generate_next_instance(task.reload)).to be_nil
      end
    end

    context "when next due date exceeds end date" do
      it "returns nil if next occurrence is after end date" do
        result = service.create_recurring_task(
          list: list,
          params: { title: "EndingSoon", due_at: Time.zone.parse("2026-02-01 10:00:00") },
          recurrence_params: { pattern: "daily", interval: 1, end_date: Date.new(2026, 2, 1) }
        )

        instance = result[:instance]
        expect(service.generate_next_instance(instance)).to be_nil
      end
    end

    context "with weekly recurrence without explicit days" do
      it "uses the current weekday as default" do
        # Create a daily recurring first to pass validation, then change to weekly
        result = service.create_recurring_task(
          list: list,
          params: { title: "WeeklyNoDays", due_at: Time.zone.parse("2026-02-02 10:00:00") }, # Monday
          recurrence_params: { pattern: "daily", interval: 1 }
        )

        # Change to weekly without days to test default behavior
        result[:template].update_columns(recurrence_pattern: "weekly", recurrence_days: nil)

        instance = result[:instance]
        next_instance = service.generate_next_instance(instance)

        expect(next_instance).to be_present
        expect(next_instance.due_at.wday).to eq(instance.due_at.wday)
      end
    end

    context "with nil recurrence_time" do
      it "uses beginning of day" do
        result = service.create_recurring_task(
          list: list,
          params: { title: "NoTime", due_at: Time.zone.parse("2026-02-01 00:00:00") },
          recurrence_params: { pattern: "daily", interval: 1 }
        )

        result[:template].update_column(:recurrence_time, nil)

        instance = result[:instance]
        next_instance = service.generate_next_instance(instance)

        expect(next_instance).to be_present
      end
    end

    context "with nil instance_number" do
      it "treats nil as 0 and increments to 1" do
        result = service.create_recurring_task(
          list: list,
          params: { title: "NilNumber", due_at: Time.zone.parse("2026-02-01 10:00:00") },
          recurrence_params: { pattern: "daily", interval: 1 }
        )

        instance = result[:instance]
        instance.update_column(:instance_number, nil)

        next_instance = service.generate_next_instance(instance.reload)
        expect(next_instance.instance_number).to eq(1)
      end
    end
  end
end
