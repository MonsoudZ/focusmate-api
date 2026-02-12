# frozen_string_literal: true

require "rails_helper"

RSpec.describe StreakService do
  let(:user) { create(:user, current_streak: 0, longest_streak: 0, last_streak_date: nil) }
  let(:list) { create(:list, user: user) }

  def create_task_due_on(date, status: "pending", creator: user)
    create(:task,
      list: list,
      creator: creator,
      due_at: date.to_date.noon,
      status: status,
      parent_task_id: nil,
      skip_due_at_validation: true
    )
  end

  describe "#update_streak!" do
    context "when user has never been checked (first time)" do
      it "sets last_streak_date to today when no tasks are due" do
        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          described_class.new(user).update_streak!

          user.reload
          expect(user.last_streak_date).to eq(Date.new(2025, 6, 15))
          expect(user.current_streak).to eq(0)
        end
      end
    end

    context "when no tasks are due today" do
      it "marks day as checked and leaves streak unchanged" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 3)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          described_class.new(user).update_streak!

          user.reload
          expect(user.last_streak_date).to eq(Date.new(2025, 6, 15))
          expect(user.current_streak).to eq(3)
        end
      end
    end

    context "when all tasks due today are completed" do
      it "increments current_streak" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 2)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 15), status: "done")
          create_task_due_on(Date.new(2025, 6, 15), status: "done")

          described_class.new(user).update_streak!

          user.reload
          expect(user.current_streak).to eq(3)
          expect(user.last_streak_date).to eq(Date.new(2025, 6, 15))
        end
      end
    end

    context "when tasks are due today but not all completed" do
      it "does not update last_streak_date" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 2)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 15), status: "done")
          create_task_due_on(Date.new(2025, 6, 15), status: "pending")

          described_class.new(user).update_streak!

          user.reload
          expect(user.last_streak_date).to eq(Date.new(2025, 6, 14))
          expect(user.current_streak).to eq(2)
        end
      end
    end

    context "when current_streak exceeds longest_streak" do
      it "updates longest_streak" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 4, longest_streak: 4)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 15), status: "done")

          described_class.new(user).update_streak!

          user.reload
          expect(user.current_streak).to eq(5)
          expect(user.longest_streak).to eq(5)
        end
      end

      it "does not update longest_streak when current_streak is lower" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 1, longest_streak: 10)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 15), status: "done")

          described_class.new(user).update_streak!

          user.reload
          expect(user.current_streak).to eq(2)
          expect(user.longest_streak).to eq(10)
        end
      end
    end

    context "when checking previous days" do
      it "resets streak when tasks were missed on a previous day" do
        user.update!(last_streak_date: Date.new(2025, 6, 12), current_streak: 5)

        # June 13 had tasks that were NOT completed (streak break)
        travel_to Time.zone.local(2025, 6, 13, 12, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 13), status: "pending")
        end

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          described_class.new(user).update_streak!

          user.reload
          expect(user.current_streak).to eq(0)
        end
      end

      it "continues streak when tasks were completed on previous days" do
        user.update!(last_streak_date: Date.new(2025, 6, 12), current_streak: 3)

        # June 13 had tasks that were completed
        travel_to Time.zone.local(2025, 6, 13, 12, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 13), status: "done")
        end

        # June 14 had tasks that were completed
        travel_to Time.zone.local(2025, 6, 14, 12, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 14), status: "done")
        end

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          described_class.new(user).update_streak!

          user.reload
          # +1 for June 13, +1 for June 14 (previous days only; today has no tasks so neutral)
          expect(user.current_streak).to eq(5)
        end
      end
    end

    context "when previous days have no tasks" do
      it "does not break the streak (neutral days)" do
        user.update!(last_streak_date: Date.new(2025, 6, 12), current_streak: 3)

        # June 13 and 14 have no tasks at all

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          described_class.new(user).update_streak!

          user.reload
          expect(user.current_streak).to eq(3)
        end
      end
    end

    context "when subtasks and soft-deleted tasks exist" do
      it "ignores subtasks (parent_task_id is not nil)" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 2)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          parent = create_task_due_on(Date.new(2025, 6, 15), status: "done")
          # Subtask that is pending -- should be ignored by streak service
          create(:task,
            list: list,
            creator: user,
            due_at: Date.new(2025, 6, 15).noon,
            status: "pending",
            parent_task: parent
          )

          described_class.new(user).update_streak!

          user.reload
          # Only the parent task matters, and it is done
          expect(user.current_streak).to eq(3)
        end
      end

      it "ignores soft-deleted tasks" do
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 2)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          create_task_due_on(Date.new(2025, 6, 15), status: "done")
          # Soft-deleted pending task -- should be ignored
          deleted_task = create_task_due_on(Date.new(2025, 6, 15), status: "pending")
          deleted_task.soft_delete!

          described_class.new(user).update_streak!

          user.reload
          expect(user.current_streak).to eq(3)
        end
      end
    end

    context "when tasks belong to a different creator" do
      it "does not count tasks created by other users" do
        other_user = create(:user)
        user.update!(last_streak_date: Date.new(2025, 6, 14), current_streak: 2)

        travel_to Time.zone.local(2025, 6, 15, 10, 0, 0) do
          # Task created by another user -- should not affect this user's streak
          create_task_due_on(Date.new(2025, 6, 15), status: "pending", creator: other_user)

          described_class.new(user).update_streak!

          user.reload
          # No tasks for this user today, so neutral day
          expect(user.last_streak_date).to eq(Date.new(2025, 6, 15))
          expect(user.current_streak).to eq(2)
        end
      end
    end

    context "when already checked today" do
      it "does not re-process the day" do
        user.update!(last_streak_date: Date.current, current_streak: 5)

        expect {
          described_class.new(user).update_streak!
          user.reload
        }.not_to change(user, :current_streak)
      end
    end

    context "query efficiency" do
      it "uses a single tasks query to evaluate day completion" do
        target_date = Date.new(2025, 6, 15)
        create_task_due_on(target_date, status: "done")
        create_task_due_on(target_date, status: "pending")

        queries = []
        callback = lambda do |_name, _start, _finish, _id, payload|
          sql = payload[:sql].to_s
          next if sql.include?("SCHEMA")
          next if sql.start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE SAVEPOINT")

          queries << sql
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          described_class.new(user).send(:check_day_completion, target_date)
        end

        task_selects = queries.count { |sql| sql.start_with?("SELECT") && sql.include?("FROM \"tasks\"") }
        expect(task_selects).to eq(1)
      end
    end
  end
end
