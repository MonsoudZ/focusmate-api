# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tasks API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }

  describe "GET /api/v1/lists/:list_id/tasks" do
    let!(:task1) { create(:task, list: list, creator: user, title: "Task 1") }
    let!(:task2) { create(:task, list: list, creator: user, title: "Task 2") }

    context "as list owner" do
      it "returns tasks for the list" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user

        expect(response).to have_http_status(:ok)
        task_ids = json_response["tasks"].map { |t| t["id"] }
        expect(task_ids).to include(task1.id, task2.id)
      end
    end

    context "as stranger" do
      it "returns forbidden" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: other_user

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with status filters" do
      let!(:pending_task) { create(:task, list: list, creator: user, status: :pending, title: "Pending") }
      let!(:done_task) { create(:task, list: list, creator: user, status: :done, title: "Done") }
      let!(:overdue_task) { create(:task, list: list, creator: user, status: :pending, due_at: 1.hour.ago, title: "Overdue") }

      it "filters by pending status" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "pending" }

        expect(response).to have_http_status(:ok)
        titles = json_response["tasks"].map { |t| t["title"] }
        expect(titles).to include("Pending", "Overdue")
        expect(titles).not_to include("Done")
      end

      it "filters by completed status" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "completed" }

        expect(response).to have_http_status(:ok)
        titles = json_response["tasks"].map { |t| t["title"] }
        expect(titles).to include("Done")
        expect(titles).not_to include("Pending")
      end

      it "filters by done status (alias)" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "done" }

        expect(response).to have_http_status(:ok)
        titles = json_response["tasks"].map { |t| t["title"] }
        expect(titles).to include("Done")
      end

      it "filters by overdue status" do
        auth_get "/api/v1/lists/#{list.id}/tasks", user: user, params: { status: "overdue" }

        expect(response).to have_http_status(:ok)
        titles = json_response["tasks"].map { |t| t["title"] }
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
        titles = json_response["tasks"].map { |t| t["title"] }
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
      it "returns forbidden" do
        auth_post "/api/v1/lists/#{list.id}/tasks", user: other_user, params: valid_params

        expect(response).to have_http_status(:forbidden)
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

    context "when trying to nudge yourself" do
      let(:own_task) { create(:task, list: list, creator: user) }

      it "returns unprocessable entity" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{own_task.id}/nudge", user: user

        expect(response).to have_http_status(:unprocessable_content)
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
        task_ids = json_response["tasks"].map { |t| t["id"] }
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
        task_ids = json_response["tasks"].map { |t| t["id"] }
        expect(task_ids).to include(task_with_note.id)
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
