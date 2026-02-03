# frozen_string_literal: true

require "rails_helper"

RSpec.describe "List Sharing & Collaboration Flow E2E", type: :request do
  let(:owner) { create(:user, name: "List Owner") }
  let(:collaborator) { create(:user, name: "Collaborator") }
  let(:viewer_user) { create(:user, name: "Viewer") }

  describe "complete list sharing lifecycle" do
    it "create list → invite → accept → collaborate → remove member" do
      # ==========================================
      # Step 1: Owner creates a list
      # ==========================================
      auth_post "/api/v1/lists",
                user: owner,
                params: { list: { name: "Shared Project", visibility: "shared" } }

      expect(response).to have_http_status(:created)
      list_id = json_response["list"]["id"]
      expect(json_response["list"]["name"]).to eq("Shared Project")

      # ==========================================
      # Step 2: Owner creates a task in the list
      # ==========================================
      auth_post "/api/v1/lists/#{list_id}/tasks",
                user: owner,
                params: { task: { title: "First task by owner", due_at: 1.day.from_now.iso8601 } }

      expect(response).to have_http_status(:created)
      owner_task_id = json_response["task"]["id"]

      # ==========================================
      # Step 3: Collaborator cannot see the list yet
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}", user: collaborator

      expect(response).to have_http_status(:not_found)

      # ==========================================
      # Step 4: Owner creates an invite for editor role
      # ==========================================
      auth_post "/api/v1/lists/#{list_id}/invites",
                user: owner,
                params: { invite: { role: "editor" } }

      expect(response).to have_http_status(:created)
      invite_code = json_response["invite"]["code"]
      expect(json_response["invite"]["role"]).to eq("editor")

      # ==========================================
      # Step 5: Collaborator previews invite (no auth required)
      # ==========================================
      get "/api/v1/invites/#{invite_code}"

      expect(response).to have_http_status(:ok)
      expect(json_response["invite"]["list"]["name"]).to eq("Shared Project")
      expect(json_response["invite"]["inviter"]["name"]).to eq("List Owner")

      # ==========================================
      # Step 6: Collaborator accepts the invite
      # ==========================================
      expect {
        auth_post "/api/v1/invites/#{invite_code}/accept", user: collaborator, params: {}
      }.to change(Membership, :count).by(1)
        .and change(Friendship, :count).by(2)

      expect(response).to have_http_status(:ok)
      expect(json_response["list"]["id"]).to eq(list_id)

      # ==========================================
      # Step 7: Verify friendship was created
      # ==========================================
      expect(Friendship.friends?(owner, collaborator)).to be true

      # ==========================================
      # Step 8: Collaborator can now see the list
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}", user: collaborator

      expect(response).to have_http_status(:ok)
      expect(json_response["list"]["name"]).to eq("Shared Project")

      # ==========================================
      # Step 9: Collaborator can see tasks
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}/tasks", user: collaborator

      expect(response).to have_http_status(:ok)
      expect(json_response["tasks"].length).to eq(1)
      expect(json_response["tasks"][0]["title"]).to eq("First task by owner")

      # ==========================================
      # Step 10: Collaborator (editor) creates a task
      # ==========================================
      auth_post "/api/v1/lists/#{list_id}/tasks",
                user: collaborator,
                params: { task: { title: "Task by collaborator", due_at: 2.days.from_now.iso8601 } }

      expect(response).to have_http_status(:created)
      collaborator_task_id = json_response["task"]["id"]

      # ==========================================
      # Step 11: Owner can see collaborator's task
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}/tasks", user: owner

      expect(response).to have_http_status(:ok)
      expect(json_response["tasks"].length).to eq(2)
      task_titles = json_response["tasks"].map { |t| t["title"] }
      expect(task_titles).to include("Task by collaborator")

      # ==========================================
      # Step 12: Collaborator completes owner's task
      # ==========================================
      auth_patch "/api/v1/lists/#{list_id}/tasks/#{owner_task_id}/complete",
                 user: collaborator,
                 params: {}

      expect(response).to have_http_status(:ok)
      expect(json_response["task"]["status"]).to eq("done")

      # ==========================================
      # Step 13: Owner can see the task is completed
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}/tasks/#{owner_task_id}", user: owner

      expect(response).to have_http_status(:ok)
      expect(json_response["task"]["status"]).to eq("done")

      # ==========================================
      # Step 14: Owner views memberships
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}/memberships", user: owner

      expect(response).to have_http_status(:ok)
      expect(json_response["memberships"].length).to eq(1)
      membership = json_response["memberships"][0]
      membership_id = membership["id"]
      expect(membership["user"]["name"]).to eq("Collaborator")
      expect(membership["role"]).to eq("editor")

      # ==========================================
      # Step 15: Owner demotes collaborator to viewer
      # ==========================================
      auth_patch "/api/v1/lists/#{list_id}/memberships/#{membership_id}",
                 user: owner,
                 params: { membership: { role: "viewer" } }

      expect(response).to have_http_status(:ok)
      expect(json_response["membership"]["role"]).to eq("viewer")

      # ==========================================
      # Step 16: Collaborator (now viewer) cannot create tasks
      # ==========================================
      auth_post "/api/v1/lists/#{list_id}/tasks",
                user: collaborator,
                params: { task: { title: "Should fail", due_at: 1.day.from_now.iso8601 } }

      expect(response).to have_http_status(:forbidden)

      # ==========================================
      # Step 17: Collaborator can still view tasks
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}/tasks", user: collaborator

      expect(response).to have_http_status(:ok)
      expect(json_response["tasks"].length).to eq(2)

      # ==========================================
      # Step 18: Owner removes collaborator from list
      # ==========================================
      auth_delete "/api/v1/lists/#{list_id}/memberships/#{membership_id}", user: owner

      expect(response).to have_http_status(:no_content)

      # ==========================================
      # Step 19: Collaborator can no longer access list
      # ==========================================
      auth_get "/api/v1/lists/#{list_id}", user: collaborator

      expect(response).to have_http_status(:not_found)

      # ==========================================
      # Step 20: Friendship remains (removal doesn't unfriend)
      # ==========================================
      expect(Friendship.friends?(owner, collaborator)).to be true
    end
  end

  describe "multi-user collaboration scenarios" do
    let!(:list) { create(:list, user: owner, name: "Team Project") }

    it "multiple users with different roles" do
      # Create invites for different roles
      auth_post "/api/v1/lists/#{list.id}/invites",
                user: owner,
                params: { invite: { role: "editor" } }
      editor_invite_code = json_response["invite"]["code"]

      auth_post "/api/v1/lists/#{list.id}/invites",
                user: owner,
                params: { invite: { role: "viewer" } }
      viewer_invite_code = json_response["invite"]["code"]

      # Both users accept
      auth_post "/api/v1/invites/#{editor_invite_code}/accept", user: collaborator, params: {}
      expect(response).to have_http_status(:ok)

      auth_post "/api/v1/invites/#{viewer_invite_code}/accept", user: viewer_user, params: {}
      expect(response).to have_http_status(:ok)

      # Owner creates a task
      auth_post "/api/v1/lists/#{list.id}/tasks",
                user: owner,
                params: { task: { title: "Team task", due_at: 1.day.from_now.iso8601 } }
      task_id = json_response["task"]["id"]

      # Editor can update the task
      auth_patch "/api/v1/lists/#{list.id}/tasks/#{task_id}",
                 user: collaborator,
                 params: { task: { title: "Updated by editor" } }
      expect(response).to have_http_status(:ok)

      # Viewer cannot update the task
      auth_patch "/api/v1/lists/#{list.id}/tasks/#{task_id}",
                 user: viewer_user,
                 params: { task: { title: "Should fail" } }
      expect(response).to have_http_status(:forbidden)

      # Viewer can read the task
      auth_get "/api/v1/lists/#{list.id}/tasks/#{task_id}", user: viewer_user
      expect(response).to have_http_status(:ok)
      expect(json_response["task"]["title"]).to eq("Updated by editor")

      # Check memberships shows all members
      auth_get "/api/v1/lists/#{list.id}/memberships", user: owner
      expect(response).to have_http_status(:ok)
      expect(json_response["memberships"].length).to eq(2)
    end
  end

  describe "invite edge cases" do
    let!(:list) { create(:list, user: owner) }

    it "invite with usage limit" do
      # Create invite with max 1 use
      auth_post "/api/v1/lists/#{list.id}/invites",
                user: owner,
                params: { invite: { role: "editor", max_uses: 1 } }

      invite_code = json_response["invite"]["code"]

      # First user accepts
      auth_post "/api/v1/invites/#{invite_code}/accept", user: collaborator, params: {}
      expect(response).to have_http_status(:ok)

      # Second user cannot use exhausted invite
      auth_post "/api/v1/invites/#{invite_code}/accept", user: viewer_user, params: {}
      expect(response).to have_http_status(:gone)
      expect(json_response["error"]["message"]).to include("usage limit")
    end

    it "cannot accept same invite twice" do
      auth_post "/api/v1/lists/#{list.id}/invites",
                user: owner,
                params: { invite: { role: "editor" } }
      invite_code = json_response["invite"]["code"]

      # First accept works
      auth_post "/api/v1/invites/#{invite_code}/accept", user: collaborator, params: {}
      expect(response).to have_http_status(:ok)

      # Second accept returns conflict
      auth_post "/api/v1/invites/#{invite_code}/accept", user: collaborator, params: {}
      expect(response).to have_http_status(:conflict)
    end

    it "owner cannot join their own list" do
      auth_post "/api/v1/lists/#{list.id}/invites",
                user: owner,
                params: { invite: { role: "editor" } }
      invite_code = json_response["invite"]["code"]

      auth_post "/api/v1/invites/#{invite_code}/accept", user: owner, params: {}
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]["message"]).to include("owner")
    end
  end

  describe "member self-removal" do
    let!(:list) { create(:list, user: owner) }
    let!(:membership) { create(:membership, list: list, user: collaborator, role: "editor") }

    # Note: Current API design only allows owner to manage memberships
    # Members cannot remove themselves via the memberships endpoint
    it "member cannot leave a list (only owner can manage memberships)" do
      auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: collaborator

      expect(response).to have_http_status(:forbidden)
    end

    it "owner can remove a member" do
      auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: owner

      expect(response).to have_http_status(:no_content)

      # Removed member can no longer access
      auth_get "/api/v1/lists/#{list.id}", user: collaborator
      expect(response).to have_http_status(:not_found)
    end
  end
end
