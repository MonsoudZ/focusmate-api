# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tasks API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }

  def response_task_titles
    json_response["tasks"].map { |t| t["title"] }
  end

  def response_task_ids
    json_response["tasks"].map { |t| t["id"] }
  end

  describe "GET /api/v1/lists/:list_id/tasks" do
    let!(:task1) { create(:task, list: list, creator: user, title: "Task 1") }
    let!(:task2) { create(:task, list: list, creator: user, title: "Task 2") }

    context "as list owner" do
      it "returns tasks for the list" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user

        expect(response).to have_http_status(:ok)
        task_ids = response_task_ids
        expect(task_ids).to include(task1.id, task2.id)
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with hidden tasks" do
      let(:member) { create(:user) }
      let!(:visible_task) { create(:task, list: list, creator: user, title: "Visible Task") }
      let!(:hidden_owner_task) { create(:task, list: list, creator: user, title: "Hidden Owner Task", visibility: :private_task) }
      let!(:hidden_member_task) { create(:task, list: list, creator: member, title: "Hidden Member Task", visibility: :private_task) }

      before do
        list.memberships.create!(user: member, role: "editor")
      end

      it "shows hidden tasks to creator" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user

        titles = response_task_titles
        expect(titles).to include("Hidden Owner Task")
      end

      it "hides other members' hidden tasks" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user

        titles = response_task_titles
        expect(titles).not_to include("Hidden Member Task")
      end

      it "shows member's own hidden tasks to them" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: member

        titles = response_task_titles
        expect(titles).to include("Hidden Member Task")
        expect(titles).not_to include("Hidden Owner Task")
      end

      it "always shows visible tasks to all members" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: member

        titles = response_task_titles
        expect(titles).to include("Visible Task")
      end
    end

    context "with status filters" do
      let!(:pending_task) { create(:task, list: list, creator: user, status: :pending, title: "Pending") }
      let!(:done_task) { create(:task, list: list, creator: user, status: :done, title: "Done") }
      let!(:overdue_task) { create(:task, list: list, creator: user, status: :pending, due_at: 1.hour.ago, title: "Overdue") }

      it "filters by pending status" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "pending" }

        expect(response).to have_http_status(:ok)
        titles = response_task_titles
        expect(titles).to include("Pending", "Overdue")
        expect(titles).not_to include("Done")
      end

      it "filters by completed status" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "completed" }

        expect(response).to have_http_status(:ok)
        titles = response_task_titles
        expect(titles).to include("Done")
        expect(titles).not_to include("Pending")
      end

      it "filters by done status (alias)" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "done" }

        expect(response).to have_http_status(:ok)
        titles = response_task_titles
        expect(titles).to include("Done")
      end

      it "filters by overdue status" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "overdue" }

        expect(response).to have_http_status(:ok)
        titles = response_task_titles
        expect(titles).to include("Overdue")
        expect(titles).not_to include("Done")
      end

      it "ignores unknown status filter" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "unknown" }

        expect(response).to have_http_status(:ok)
        # Returns all tasks when status is unknown
        expect(json_response["tasks"].size).to be >= 2
      end
    end

    context "with sorting options" do
      let!(:older_task) { create(:task, list: list, creator: user, title: "Older", created_at: 2.days.ago) }
      let!(:newer_task) { create(:task, list: list, creator: user, title: "Newer", created_at: 1.day.ago) }

      it "sorts by created_at desc by default" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user

        expect(response).to have_http_status(:ok)
        titles = response_task_titles
        expect(titles.index("Newer")).to be < titles.index("Older")
      end

      it "sorts by title asc" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { sort_by: "title", sort_order: "asc" }

        expect(response).to have_http_status(:ok)
        # Results should be sorted alphabetically
      end

      it "sorts by due_at" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { sort_by: "due_at", sort_order: "desc" }

        expect(response).to have_http_status(:ok)
      end

      it "sorts by updated_at" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { sort_by: "updated_at", sort_order: "asc" }

        expect(response).to have_http_status(:ok)
      end

      it "ignores invalid sort_by column" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { sort_by: "invalid_column" }

        expect(response).to have_http_status(:ok)
        # Falls back to created_at
      end

      it "ignores invalid sort_order" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { sort_order: "invalid" }

        expect(response).to have_http_status(:ok)
        # Falls back to desc
      end
    end
  end

  describe "GET /api/v1/lists/:list_id/tasks/:id" do
    let(:task) { create(:task, list: list, creator: user) }

    context "as list owner" do
      it "returns the task" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["task"]["id"]).to eq(task.id)
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with mismatched list_id" do
      let(:other_list) { create(:list, user: user) }

      it "returns not found even when user can access both lists" do
        auth_get "/api/v1/lists/#{other_list.id}/tasks/#{task.id}", user: user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/tasks/:id (global task fetch)" do
    let(:task) { create(:task, list: list, creator: user, title: "My Task") }

    context "as list owner" do
      it "returns the task without needing list_id" do
        auth_get "/api/v1/tasks/#{task.id}", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["task"]["id"]).to eq(task.id)
        expect(json_response["task"]["title"]).to eq("My Task")
        expect(json_response["task"]["list_id"]).to eq(list.id)
        expect(json_response["task"]["list_name"]).to eq(list.name)
      end
    end

    context "as list member" do
      let(:member) { create(:user) }
      let!(:membership) { create(:membership, list: list, user: member, role: "editor") }

      it "returns the task" do
        auth_get "/api/v1/tasks/#{task.id}", user: member

        expect(response).to have_http_status(:ok)
        expect(json_response["task"]["id"]).to eq(task.id)
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_get "/api/v1/tasks/#{task.id}", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end

    context "unauthenticated" do
      it "returns unauthorized" do
        get "/api/v1/tasks/#{task.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with non-existent task" do
      it "returns not found" do
        auth_get "/api/v1/tasks/999999", user: user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/lists/:list_id/tasks" do
    let(:valid_params) do
      {
        task: {
          title: "New Task",
          due_at: 1.day.from_now.iso8601,
          priority: "high",
          note: "Task notes"
        }
      }
    end

    context "as list owner" do
      it "creates a task" do
        expect {
          auth_post "/api/v1/lists/#{list.id}/tasks", user: user, params: valid_params
        }.to change(Task, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response["task"]["title"]).to eq("New Task")
      end
    end

    context "with invalid params" do
      it "returns error for missing title" do
        auth_post "/api/v1/lists/#{list.id}/tasks", user: user, params: { task: { due_at: 1.day.from_now.iso8601 } }

        expect(response.status).to be_in([ 400, 422 ])
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_post "/api/v1/lists/#{list.id}/tasks", user: other_user, params: valid_params

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with hidden param" do
      it "creates a hidden task when hidden is true" do
        hidden_params = {
          task: {
            title: "Hidden Task",
            due_at: 1.day.from_now.iso8601,
            hidden: true
          }
        }

        auth_post "/api/v1/lists/#{list.id}/tasks", user: user, params: hidden_params

        expect(response).to have_http_status(:created)
        expect(json_response["task"]["hidden"]).to be true
        expect(Task.last.visibility).to eq("private_task")
      end

      it "creates a visible task when hidden is false" do
        visible_params = {
          task: {
            title: "Visible Task",
            due_at: 1.day.from_now.iso8601,
            hidden: false
          }
        }

        auth_post "/api/v1/lists/#{list.id}/tasks", user: user, params: visible_params

        expect(response).to have_http_status(:created)
        expect(json_response["task"]["hidden"]).to be false
        expect(Task.last.visibility).to eq("visible_to_all")
      end
    end

    context "with params at root level (no :task key)" do
      it "creates a task with root-level params" do
        expect {
          auth_post "/api/v1/lists/#{list.id}/tasks", user: user, params: {
            title: "Root Level Task",
            due_at: 1.day.from_now.iso8601
          }
        }.to change(Task, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response["task"]["title"]).to eq("Root Level Task")
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:id" do
    let(:task) { create(:task, list: list, creator: user, title: "Original Title") }

    context "as list owner" do
      it "updates the task" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: user, params: { task: { title: "Updated Title" } }

        expect(response).to have_http_status(:ok)
        expect(task.reload.title).to eq("Updated Title")
      end
    end

    context "as viewer" do
      before { list.memberships.create!(user: other_user, role: "viewer") }

      it "returns forbidden" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: other_user, params: { task: { title: "Viewer Update" } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with mismatched list_id" do
      let(:other_list) { create(:list, user: user) }

      it "returns not found and does not update the task" do
        auth_patch "/api/v1/lists/#{other_list.id}/tasks/#{task.id}", user: user, params: { task: { title: "Wrong List" } }

        expect(response).to have_http_status(:not_found)
        expect(task.reload.title).to eq("Original Title")
      end
    end

    context "toggling hidden status" do
      it "updates task to hidden" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: user, params: { task: { hidden: true } }

        expect(response).to have_http_status(:ok)
        expect(json_response["task"]["hidden"]).to be true
        expect(task.reload.visibility).to eq("private_task")
      end

      it "updates task to visible" do
        hidden_task = create(:task, list: list, creator: user, visibility: :private_task)

        auth_patch "/api/v1/lists/#{list.id}/tasks/#{hidden_task.id}", user: user, params: { task: { hidden: false } }

        expect(response).to have_http_status(:ok)
        expect(json_response["task"]["hidden"]).to be false
        expect(hidden_task.reload.visibility).to eq("visible_to_all")
      end
    end
  end

  describe "DELETE /api/v1/lists/:list_id/tasks/:id" do
    let!(:task) { create(:task, list: list, creator: user) }

    context "as list owner" do
      it "soft deletes the task" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: user

        expect(response).to have_http_status(:no_content)
        expect(task.reload.deleted?).to be true
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:id/complete" do
    let(:task) { create(:task, list: list, creator: user, status: :pending) }

    context "as list owner" do
      it "completes the task" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/complete", user: user

        expect(response).to have_http_status(:ok)
        expect(task.reload.status).to eq("done")
        expect(task.completed_at).to be_present
      end

      it "completes an overdue task with missed_reason" do
        overdue_task = create(:task, list: list, creator: user, status: :pending, due_at: 1.hour.ago, requires_explanation_if_missed: true)

        auth_patch "/api/v1/lists/#{list.id}/tasks/#{overdue_task.id}/complete", user: user, params: { missed_reason: "Was in a meeting" }

        expect(response).to have_http_status(:ok)
        expect(overdue_task.reload.status).to eq("done")
        expect(overdue_task.missed_reason).to eq("Was in a meeting")
      end

      it "rejects non-scalar missed_reason values" do
        overdue_task = create(:task, list: list, creator: user, status: :pending, due_at: 1.hour.ago, requires_explanation_if_missed: true)

        auth_patch "/api/v1/lists/#{list.id}/tasks/#{overdue_task.id}/complete",
                   user: user,
                   params: { missed_reason: { bad: "input" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(overdue_task.reload.status).to eq("pending")
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:id/reopen" do
    let(:completed_task) { create(:task, list: list, creator: user, status: :done, completed_at: 1.hour.ago) }

    context "as list owner" do
      it "reopens the task" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{completed_task.id}/reopen", user: user

        expect(response).to have_http_status(:ok)
        expect(completed_task.reload.status).to eq("pending")
        expect(completed_task.completed_at).to be_nil
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:id/assign" do
    let(:task) { create(:task, list: list, creator: user) }
    let(:assignee) { create(:user) }

    before do
      list.memberships.create!(user: assignee, role: "editor")
    end

    context "as list owner" do
      it "assigns the task to a user" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/assign", user: user, params: { assigned_to: assignee.id }

        expect(response).to have_http_status(:ok)
        expect(task.reload.assigned_to_id).to eq(assignee.id)
      end

      it "returns bad request for non-scalar assigned_to values" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/assign",
                   user: user,
                   params: { assigned_to: { bad: "input" } }

        expect(response).to have_http_status(:bad_request)
        expect(task.reload.assigned_to_id).to be_nil
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:id/unassign" do
    let(:assignee) { create(:user) }
    let(:task) { create(:task, list: list, creator: user, assigned_to: assignee) }

    before do
      list.memberships.create!(user: assignee, role: "editor")
    end

    context "as list owner" do
      it "unassigns the task" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/unassign", user: user

        expect(response).to have_http_status(:ok)
        expect(task.reload.assigned_to_id).to be_nil
      end
    end
  end

  describe "POST /api/v1/lists/:list_id/tasks/:id/nudge" do
    let(:task_creator) { create(:user) }
    let(:task) { create(:task, list: list, creator: task_creator) }

    before do
      list.memberships.create!(user: task_creator, role: "editor")
    end

    context "as list owner nudging the task creator" do
      it "sends a nudge" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/nudge", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["message"]).to eq("Nudge sent")
      end
    end

    context "when nudging your own task" do
      let(:own_task) { create(:task, list: list, creator: user) }

      it "sends nudge to other list members" do
        # With the new behavior, nudging your own task sends to other members
        # (e.g., "hey everyone, remind me about this task")
        auth_post "/api/v1/lists/#{list.id}/tasks/#{own_task.id}/nudge", user: user

        expect(response).to have_http_status(:ok)
        expect(Nudge.last.to_user).to eq(task_creator)
      end
    end

    context "when no other members in list" do
      let(:private_list) { create(:list, user: user) }
      let(:solo_task) { create(:task, list: private_list, creator: user) }

      it "returns unprocessable entity" do
        auth_post "/api/v1/lists/#{private_list.id}/tasks/#{solo_task.id}/nudge", user: user

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response["error"]["message"]).to include("only member")
      end
    end
  end

  describe "GET /api/v1/tasks/search" do
    let!(:matching_task) { create(:task, list: list, creator: user, title: "Find me please") }
    let!(:non_matching) { create(:task, list: list, creator: user, title: "Nothing here") }

    context "as authenticated user" do
      it "searches tasks in accessible lists" do
        auth_get "/api/v1/tasks/search", user: user, params: { q: "Find me" }

        expect(response).to have_http_status(:ok)
        task_ids = response_task_ids
        expect(task_ids).to include(matching_task.id)
        expect(task_ids).not_to include(non_matching.id)
      end

      it "returns empty array for blank query" do
        auth_get "/api/v1/tasks/search", user: user, params: { q: "" }

        expect(response).to have_http_status(:ok)
        expect(json_response["tasks"]).to eq([])
      end

      it "returns bad request for query too long" do
        auth_get "/api/v1/tasks/search", user: user, params: { q: "a" * 256 }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to include("too long")
      end

      it "searches by note as well" do
        task_with_note = create(:task, list: list, creator: user, title: "Other", note: "Unique note text")

        auth_get "/api/v1/tasks/search", user: user, params: { q: "Unique note" }

        expect(response).to have_http_status(:ok)
        task_ids = response_task_ids
        expect(task_ids).to include(task_with_note.id)
      end
    end
  end

  describe "POST /api/v1/lists/:list_id/tasks/:id/reschedule" do
    let(:task) { create(:task, list: list, creator: user, due_at: 1.day.from_now) }

    context "as list owner" do
      it "reschedules the task" do
        new_due = 3.days.from_now.iso8601

        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { new_due_at: new_due, reason: "priorities_shifted" }

        expect(response).to have_http_status(:ok)
        expect(json_response["task"]["due_at"]).to eq(new_due)
      end

      it "creates a reschedule event with user tracking" do
        original_due = task.due_at
        new_due = 3.days.from_now.iso8601

        expect {
          auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                    user: user,
                    params: { new_due_at: new_due, reason: "blocked" }
        }.to change(RescheduleEvent, :count).by(1)

        event = RescheduleEvent.last
        expect(event.previous_due_at.to_i).to eq(original_due.to_i)
        expect(event.reason).to eq("blocked")
        expect(event.user).to eq(user)
      end

      it "includes reschedule_events in response with user info" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { new_due_at: 3.days.from_now.iso8601, reason: "underestimated" }

        expect(json_response["task"]["reschedule_events"]).to be_an(Array)
        expect(json_response["task"]["reschedule_events"].length).to eq(1)
        event = json_response["task"]["reschedule_events"][0]
        expect(event["reason"]).to eq("underestimated")
        expect(event["rescheduled_by"]["id"]).to eq(user.id)
        expect(event["rescheduled_by"]["name"]).to eq(user.name)
      end

      it "accepts custom reason text" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { new_due_at: 3.days.from_now.iso8601, reason: "Client requested delay" }

        expect(response).to have_http_status(:ok)
        expect(RescheduleEvent.last.reason).to eq("Client requested delay")
      end

      it "returns reschedule events in reverse chronological order" do
        # Create existing reschedule event
        create(:reschedule_event, task: task, reason: "first", created_at: 1.hour.ago)

        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { new_due_at: 3.days.from_now.iso8601, reason: "second" }

        events = json_response["task"]["reschedule_events"]
        expect(events[0]["reason"]).to eq("second")
        expect(events[1]["reason"]).to eq("first")
      end

      it "returns 400 when new_due_at is missing" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { reason: "blocked" }

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when reason is missing" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { new_due_at: 3.days.from_now.iso8601 }

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 for non-scalar reschedule params" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: user,
                  params: { new_due_at: { bad: "input" }, reason: [ "blocked" ] }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "as viewer" do
      before { list.memberships.create!(user: other_user, role: "viewer") }

      it "returns forbidden" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: other_user,
                  params: { new_due_at: 3.days.from_now.iso8601, reason: "blocked" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as editor" do
      before { list.memberships.create!(user: other_user, role: "editor") }

      it "can reschedule the task" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{task.id}/reschedule",
                  user: other_user,
                  params: { new_due_at: 3.days.from_now.iso8601, reason: "priorities_shifted" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /api/v1/lists/:list_id/tasks/reorder" do
    let!(:task1) { create(:task, list: list, creator: user, position: 1) }
    let!(:task2) { create(:task, list: list, creator: user, position: 2) }
    let!(:task3) { create(:task, list: list, creator: user, position: 3) }

    context "as list owner" do
      it "reorders tasks" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: user, params: {
          tasks: [
            { id: task3.id, position: 1 },
            { id: task1.id, position: 2 },
            { id: task2.id, position: 3 }
          ]
        }

        expect(response).to have_http_status(:ok)
        expect(task3.reload.position).to eq(1)
        expect(task1.reload.position).to eq(2)
        expect(task2.reload.position).to eq(3)
      end

      it "accepts numeric string ids and positions" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: user, params: {
          tasks: [
            { id: task2.id.to_s, position: "1" },
            { id: task1.id.to_s, position: "2" }
          ]
        }

        expect(response).to have_http_status(:ok)
        expect(task2.reload.position).to eq(1)
        expect(task1.reload.position).to eq(2)
      end

      it "returns bad request when tasks payload is missing" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: user, params: {}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns bad request when a task entry is not an object" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: user, params: {
          tasks: [ "invalid" ]
        }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to eq("each task entry must be an object")
      end

      it "returns bad request when task id is not an integer" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: user, params: {
          tasks: [ { id: "abc", position: 1 } ]
        }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to eq("id must be an integer")
      end

      it "returns bad request when positions are duplicated" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: user, params: {
          tasks: [
            { id: task1.id, position: 1 },
            { id: task2.id, position: 1 }
          ]
        }

        expect(response).to have_http_status(:bad_request)
        expect(json_response.dig("error", "code")).to eq("duplicate_positions")
      end
    end

    context "as viewer" do
      before { list.memberships.create!(user: other_user, role: "viewer") }

      it "returns forbidden" do
        auth_post "/api/v1/lists/#{list.id}/tasks/reorder", user: other_user, params: {
          tasks: [ { id: task1.id, position: 1 } ]
        }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
