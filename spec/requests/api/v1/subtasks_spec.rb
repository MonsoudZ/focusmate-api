# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subtasks API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:list) { create(:list, user: user) }
  let(:parent_task) { create(:task, list: list, creator: user) }
  let!(:subtask1) { create(:task, list: list, creator: user, parent_task: parent_task, title: "Subtask 1", position: 1) }
  let!(:subtask2) { create(:task, list: list, creator: user, parent_task: parent_task, title: "Subtask 2", position: 2) }

  describe "GET /api/v1/lists/:list_id/tasks/:task_id/subtasks" do
    context "as list owner" do
      it "returns subtasks for the parent task" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks", user: user

        expect(response).to have_http_status(:ok)
        subtask_ids = json_response["subtasks"].map { |s| s["id"] }
        expect(subtask_ids).to include(subtask1.id, subtask2.id)
      end

      it "excludes soft-deleted subtasks" do
        subtask1.soft_delete!

        auth_get "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks", user: user

        subtask_ids = json_response["subtasks"].map { |s| s["id"] }
        expect(subtask_ids).not_to include(subtask1.id)
        expect(subtask_ids).to include(subtask2.id)
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/lists/:list_id/tasks/:task_id/subtasks" do
    context "as list owner" do
      it "creates a subtask" do
        expect {
          auth_post "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks",
                    user: user,
                    params: { subtask: { title: "New Subtask" } }
        }.to change(Task, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response["title"]).to eq("New Subtask")
        expect(json_response["parent_task_id"]).to eq(parent_task.id)
      end

      it "accepts unwrapped params" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks",
                  user: user,
                  params: { title: "Unwrapped Subtask" }

        expect(response).to have_http_status(:created)
        expect(json_response["title"]).to eq("Unwrapped Subtask")
      end

      it "assigns the next position automatically" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks",
                  user: user,
                  params: { subtask: { title: "Third Subtask" } }

        expect(response).to have_http_status(:created)
        expect(json_response["position"]).to eq(3)
      end

      it "inherits parent task attributes" do
        auth_post "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks",
                  user: user,
                  params: { subtask: { title: "Inherited Subtask" } }

        created = Task.find(json_response["id"])
        expect(created.list_id).to eq(parent_task.list_id)
        expect(created.due_at.to_i).to eq(parent_task.due_at.to_i)
        expect(created.strict_mode).to eq(parent_task.strict_mode)
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id" do
    context "as list owner" do
      it "updates the subtask" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}",
                   user: user,
                   params: { subtask: { title: "Updated Subtask" } }

        expect(response).to have_http_status(:ok)
        expect(json_response["title"]).to eq("Updated Subtask")
        expect(subtask1.reload.title).to eq("Updated Subtask")
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}",
                   user: other_user,
                   params: { subtask: { title: "Hacked" } }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id" do
    context "as list owner" do
      it "soft deletes the subtask" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}",
                    user: user

        expect(response).to have_http_status(:no_content)
        expect(subtask1.reload.deleted?).to be true
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}",
                    user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id/complete" do
    context "as list owner" do
      it "completes a pending subtask" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}/complete",
                   user: user

        expect(response).to have_http_status(:ok)
        expect(subtask1.reload.status).to eq("done")
        expect(json_response["status"]).to eq("done")
      end

      it "is idempotent when already done" do
        subtask1.complete!

        auth_patch "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}/complete",
                   user: user

        expect(response).to have_http_status(:ok)
        expect(subtask1.reload.status).to eq("done")
      end
    end

    context "as stranger" do
      it "returns not found" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}/complete",
                   user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id/reopen" do
    context "as list owner" do
      it "reopens a completed subtask" do
        subtask1.complete!

        auth_patch "/api/v1/lists/#{list.id}/tasks/#{parent_task.id}/subtasks/#{subtask1.id}/reopen",
                   user: user

        expect(response).to have_http_status(:ok)
        expect(subtask1.reload.status).to eq("pending")
      end
    end
  end
end
