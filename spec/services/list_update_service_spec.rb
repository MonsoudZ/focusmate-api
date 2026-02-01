# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListUpdateService do
  let(:owner) { create(:user) }
  let(:editor) { create(:user) }
  let(:unauthorized_user) { create(:user) }
  let(:list) { create(:list, user: owner, name: "Original Name") }

  describe "#call!" do
    context "when user is the list owner" do
      it "updates the list successfully" do
        result = described_class.call!(list: list, user: owner, attributes: { name: "Updated Name" })

        expect(result).to eq(list)
        expect(list.reload.name).to eq("Updated Name")
      end

      it "updates multiple attributes" do
        described_class.call!(list: list, user: owner, attributes: {
          name: "New Name",
          description: "New Description",
          visibility: "public"
        })

        list.reload
        expect(list.name).to eq("New Name")
        expect(list.description).to eq("New Description")
        expect(list.visibility).to eq("public")
      end

      it "returns the list object" do
        result = described_class.call!(list: list, user: owner, attributes: { name: "Test" })

        expect(result).to be_a(List)
        expect(result).to eq(list)
      end
    end

    context "when user has edit permissions via membership" do
      before do
        create(:membership, list: list, user: editor, role: "editor")
      end

      it "updates the list successfully" do
        result = described_class.call!(list: list, user: editor, attributes: { name: "Editor Updated" })

        expect(result).to eq(list)
        expect(list.reload.name).to eq("Editor Updated")
      end

      it "allows multiple attribute updates" do
        described_class.call!(list: list, user: editor, attributes: {
          name: "Edited Name",
          description: "Edited Description"
        })

        list.reload
        expect(list.name).to eq("Edited Name")
        expect(list.description).to eq("Edited Description")
      end
    end

    context "when user has viewer-only permissions" do
      before do
        create(:membership, list: list, user: unauthorized_user, role: "viewer")
      end

      it "raises Forbidden error" do
        expect {
          described_class.call!(list: list, user: unauthorized_user, attributes: { name: "Unauthorized Update" })
        }.to raise_error(ApplicationError::Forbidden, "You do not have permission to edit this list")
      end

      it "does not update the list" do
        expect {
          described_class.call!(list: list, user: unauthorized_user, attributes: { name: "Unauthorized Update" })
        }.to raise_error(ApplicationError::Forbidden)

        expect(list.reload.name).to eq("Original Name")
      end
    end

    context "when user is not the owner and has no share" do
      it "raises Forbidden error" do
        expect {
          described_class.call!(list: list, user: unauthorized_user, attributes: { name: "Unauthorized Update" })
        }.to raise_error(ApplicationError::Forbidden)
      end
    end

    context "when validation fails" do
      it "raises Validation error with details" do
        expect {
          described_class.call!(list: list, user: owner, attributes: { name: "" })
        }.to raise_error(ApplicationError::Validation) do |error|
          expect(error.message).to eq("Validation failed")
          expect(error.details).to be_a(Hash)
          expect(error.details).to have_key(:name)
        end
      end

      it "does not update the list on validation failure" do
        expect {
          described_class.call!(list: list, user: owner, attributes: { name: "" })
        }.to raise_error(ApplicationError::Validation)

        expect(list.reload.name).to eq("Original Name")
      end
    end

    context "when updating visibility" do
      it "updates visibility successfully" do
        described_class.call!(list: list, user: owner, attributes: { visibility: "public" })

        expect(list.reload.visibility).to eq("public")
      end
    end
  end
end
