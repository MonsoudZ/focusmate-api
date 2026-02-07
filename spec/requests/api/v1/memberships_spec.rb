# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Memberships", type: :request do
  let(:owner) { create(:user, name: "Owner") }
  let(:member) { create(:user, name: "Member") }
  let(:other_user) { create(:user, name: "Other") }
  let(:list) { create(:list, user: owner, name: "Test List") }

  describe "GET /api/v1/lists/:list_id/memberships" do
    context "as list owner" do
      it "returns owner and all memberships" do
        create(:membership, list: list, user: member, role: "editor")
        create(:membership, list: list, user: other_user, role: "viewer")

        auth_get "/api/v1/lists/#{list.id}/memberships", user: owner

        expect(response).to have_http_status(:ok)
        expect(json_response["owner"]).to be_present
        expect(json_response["memberships"].length).to eq(2)
      end

      it "returns owner with empty memberships when no other members" do
        auth_get "/api/v1/lists/#{list.id}/memberships", user: owner

        expect(response).to have_http_status(:ok)
        expect(json_response["owner"]["id"]).to eq(owner.id)
        expect(json_response["memberships"]).to eq([])
      end

      it "includes owner details separately" do
        auth_get "/api/v1/lists/#{list.id}/memberships", user: owner

        expect(json_response["owner"]["id"]).to eq(owner.id)
        expect(json_response["owner"]["name"]).to eq("Owner")
        expect(json_response["owner"]["email"]).to eq(owner.email)
      end

      it "includes member details in memberships array" do
        create(:membership, list: list, user: member, role: "editor")

        auth_get "/api/v1/lists/#{list.id}/memberships", user: owner

        member_entry = json_response["memberships"][0]
        expect(member_entry["id"]).to be_present
        expect(member_entry["role"]).to eq("editor")
        expect(member_entry["user"]["id"]).to eq(member.id)
        expect(member_entry["user"]["name"]).to eq("Member")
      end
    end

    context "as list member" do
      let!(:membership) { create(:membership, list: list, user: member, role: "editor") }

      it "can view owner and memberships" do
        auth_get "/api/v1/lists/#{list.id}/memberships", user: member

        expect(response).to have_http_status(:ok)
        expect(json_response["owner"]["id"]).to eq(owner.id)
        expect(json_response["memberships"].length).to eq(1)
        expect(json_response["memberships"][0]["role"]).to eq("editor")
      end
    end

    context "as non-member" do
      it "returns 404 (no info leakage)" do
        auth_get "/api/v1/lists/#{list.id}/memberships", user: other_user

        expect(response).to have_http_status(:not_found)
      end
    end

    context "unauthenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/lists/#{list.id}/memberships"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "returns 404 for a deleted list" do
      list.soft_delete!

      auth_get "/api/v1/lists/#{list.id}/memberships", user: owner

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/lists/:list_id/memberships" do
    let(:new_member) { create(:user, name: "New Member", email: "newmember@example.com") }

    context "as list owner" do
      context "adding by user_identifier (email)" do
        it "adds a member with editor role" do
          expect {
            auth_post "/api/v1/lists/#{list.id}/memberships",
                      user: owner,
                      params: { membership: { user_identifier: new_member.email, role: "editor" } }
          }.to change(Membership, :count).by(1)

          expect(response).to have_http_status(:created)
          expect(json_response["membership"]["user"]["id"]).to eq(new_member.id)
          expect(json_response["membership"]["role"]).to eq("editor")
        end

        it "adds a member with viewer role" do
          auth_post "/api/v1/lists/#{list.id}/memberships",
                    user: owner,
                    params: { membership: { user_identifier: new_member.email, role: "viewer" } }

          expect(response).to have_http_status(:created)
          expect(json_response["membership"]["role"]).to eq("viewer")
        end
      end

      context "adding by friend_id" do
        before do
          # Must be friends to add by friend_id
          Friendship.create_mutual!(owner, new_member)
        end

        it "adds a friend as member" do
          expect {
            auth_post "/api/v1/lists/#{list.id}/memberships",
                      user: owner,
                      params: { membership: { friend_id: new_member.id, role: "editor" } }
          }.to change(Membership, :count).by(1)

          expect(response).to have_http_status(:created)
        end

        it "cannot add non-friend by friend_id" do
          non_friend = create(:user)

          auth_post "/api/v1/lists/#{list.id}/memberships",
                    user: owner,
                    params: { membership: { friend_id: non_friend.id, role: "editor" } }

          expect(response).to have_http_status(:forbidden)
        end
      end

      it "returns 400 for invalid role" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { user_identifier: new_member.email, role: "admin" } }

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 409 when user is already a member" do
        create(:membership, list: list, user: new_member)

        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { user_identifier: new_member.email, role: "editor" } }

        expect(response).to have_http_status(:conflict)
      end

      it "returns 409 when adding owner as member" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { user_identifier: owner.email, role: "editor" } }

        expect(response).to have_http_status(:conflict)
      end

      it "returns 404 for non-existent user" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { user_identifier: "nonexistent@example.com", role: "editor" } }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 400 when no identifier provided" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { role: "editor" } }

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when membership payload is not an object" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: "invalid" }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to eq("membership must be an object")
      end

      it "returns 400 for non-scalar user_identifier values" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { user_identifier: { bad: "input" }, role: "viewer" } }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to eq("user_identifier or friend_id is required")
      end

      it "returns 400 for non-integer friend_id values" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: owner,
                  params: { membership: { friend_id: "abc", role: "viewer" } }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to eq("friend_id must be a positive integer")
      end
    end

    context "as list member (non-owner)" do
      let!(:membership) { create(:membership, list: list, user: member, role: "editor") }

      it "returns 403 forbidden (only owner can manage)" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: member,
                  params: { membership: { user_identifier: new_member.email, role: "editor" } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as non-member" do
      it "returns 404 (no info leakage)" do
        auth_post "/api/v1/lists/#{list.id}/memberships",
                  user: other_user,
                  params: { membership: { user_identifier: new_member.email, role: "editor" } }

        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 404 for a deleted list" do
      list.soft_delete!

      auth_post "/api/v1/lists/#{list.id}/memberships",
                user: owner,
                params: { membership: { user_identifier: new_member.email, role: "editor" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/lists/:list_id/memberships/:id" do
    let!(:membership) { create(:membership, list: list, user: member, role: "viewer") }

    context "as list owner" do
      it "updates role from viewer to editor" do
        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: owner,
                   params: { membership: { role: "editor" } }

        expect(response).to have_http_status(:ok)
        expect(json_response["membership"]["role"]).to eq("editor")
        expect(membership.reload.role).to eq("editor")
      end

      it "updates role from editor to viewer" do
        membership.update!(role: "editor")

        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: owner,
                   params: { membership: { role: "viewer" } }

        expect(response).to have_http_status(:ok)
        expect(json_response["membership"]["role"]).to eq("viewer")
      end

      it "returns 400 for invalid role" do
        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: owner,
                   params: { membership: { role: "owner" } }

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when membership payload is not an object" do
        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: owner,
                   params: { membership: "invalid" }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]["message"]).to eq("membership must be an object")
      end

      it "returns 404 for membership in different list" do
        other_list = create(:list, user: owner)
        other_membership = create(:membership, list: other_list, user: other_user)

        auth_patch "/api/v1/lists/#{list.id}/memberships/#{other_membership.id}",
                   user: owner,
                   params: { membership: { role: "editor" } }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as the member themselves" do
      it "cannot change own role" do
        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: member,
                   params: { membership: { role: "editor" } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as another member" do
      let!(:editor_membership) { create(:membership, list: list, user: other_user, role: "editor") }

      it "cannot change other member's role" do
        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: other_user,
                   params: { membership: { role: "editor" } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as non-member" do
      let(:outsider) { create(:user) }

      it "returns 404 (no info leakage)" do
        auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                   user: outsider,
                   params: { membership: { role: "editor" } }

        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 404 for a deleted list" do
      list.soft_delete!

      auth_patch "/api/v1/lists/#{list.id}/memberships/#{membership.id}",
                 user: owner,
                 params: { membership: { role: "editor" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/lists/:list_id/memberships/:id" do
    let!(:membership) { create(:membership, list: list, user: member, role: "editor") }

    context "as list owner" do
      it "removes the member" do
        expect {
          auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: owner
        }.to change(Membership, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it "removed member loses access" do
        auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: owner

        auth_get "/api/v1/lists/#{list.id}", user: member
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for non-existent membership" do
        auth_delete "/api/v1/lists/#{list.id}/memberships/999999", user: owner

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for membership in different list" do
        other_list = create(:list, user: owner)
        other_membership = create(:membership, list: other_list, user: other_user)

        auth_delete "/api/v1/lists/#{list.id}/memberships/#{other_membership.id}", user: owner

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as the member themselves" do
      # Note: Self-removal requires manage_memberships? permission which only owner has
      # Members cannot remove themselves via this endpoint
      it "cannot remove themselves (only owner can manage memberships)" do
        auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: member

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as another member" do
      let!(:other_membership) { create(:membership, list: list, user: other_user, role: "editor") }

      it "cannot remove other members" do
        auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: other_user

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as non-member" do
      let(:outsider) { create(:user) }

      it "returns 404 (no info leakage)" do
        auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: outsider

        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 404 for a deleted list" do
      list.soft_delete!

      auth_delete "/api/v1/lists/#{list.id}/memberships/#{membership.id}", user: owner

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "membership role effects on task operations" do
    let!(:task) { create(:task, list: list, creator: owner, title: "Test Task", due_at: 1.day.from_now) }

    context "as editor" do
      let!(:editor_membership) { create(:membership, list: list, user: member, role: "editor") }

      it "can create tasks" do
        auth_post "/api/v1/lists/#{list.id}/tasks",
                  user: member,
                  params: { task: { title: "Editor's task", due_at: 1.day.from_now.iso8601 } }

        expect(response).to have_http_status(:created)
      end

      it "can update tasks" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}",
                   user: member,
                   params: { task: { title: "Updated title" } }

        expect(response).to have_http_status(:ok)
      end

      it "can complete tasks" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/complete",
                   user: member,
                   params: {}

        expect(response).to have_http_status(:ok)
      end

      it "can delete tasks" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: member

        expect(response).to have_http_status(:no_content)
      end
    end

    context "as viewer" do
      let!(:viewer_membership) { create(:membership, list: list, user: member, role: "viewer") }

      it "can read tasks" do
        auth_get "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: member

        expect(response).to have_http_status(:ok)
      end

      it "cannot create tasks" do
        auth_post "/api/v1/lists/#{list.id}/tasks",
                  user: member,
                  params: { task: { title: "Viewer's task", due_at: 1.day.from_now.iso8601 } }

        expect(response).to have_http_status(:forbidden)
      end

      it "cannot update tasks" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}",
                   user: member,
                   params: { task: { title: "Updated title" } }

        expect(response).to have_http_status(:forbidden)
      end

      it "cannot complete tasks" do
        auth_patch "/api/v1/lists/#{list.id}/tasks/#{task.id}/complete",
                   user: member,
                   params: {}

        expect(response).to have_http_status(:forbidden)
      end

      it "cannot delete tasks" do
        auth_delete "/api/v1/lists/#{list.id}/tasks/#{task.id}", user: member

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
