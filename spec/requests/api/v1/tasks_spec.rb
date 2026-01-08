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
  end

  describe "GET /api/v1/lists/:list_id/tasks/:id" do
    let(:task) { create(:task, list: list, creator: user) }

    context "as list owner" do
      it "returns the task" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: user

        expect(response).to have_http_status(:ok)
        expect(json_response["id"]).to eq(task.id)
      end
    end

    context "as stranger" do
      it "returns forbidden" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: other_user

        expect(response).to have_http_status(:forbidden)
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
        expect(json_response["title"]).to eq("New Task")
      end
    end

    context "with invalid params" do
      it "returns error for missing title" do
        auth_post "/api/v1/lists/#{list.id}/tasks", user: user, params: { task: { due_at: 1.day.from_now.iso8601 } }

        expect(response.status).to be_in([400, 422])
      end
    end

    context "as stranger" do
      it "returns forbidden" do
        auth_post "/api/v1/lists/#{list.id}/tasks", user: other_user, params: valid_params

        expect(response).to have_http_status(:forbidden)
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
      it "returns forbidden" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: other_user

        expect(response).to have_http_status(:forbidden)
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
          tasks: [{ id: task1.id, position: 1 }]
        }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end