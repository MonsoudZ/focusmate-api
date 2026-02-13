# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditableLists do
  let(:user) { create(:user) }
  let(:test_instance) do
    klass = Class.new do
      include EditableLists
      attr_reader :current_user

      def initialize(user)
        @current_user = user
      end
    end
    klass.new(user)
  end

  describe "#editable_list_ids" do
    it "returns list ids where user is an editor" do
      list = create(:list, user: create(:user))
      create(:membership, list: list, user: user, role: "editor")

      expect(test_instance.send(:editable_list_ids)).to include(list.id)
    end

    it "excludes lists where user is a viewer" do
      list = create(:list, user: create(:user))
      create(:membership, list: list, user: user, role: "viewer")

      expect(test_instance.send(:editable_list_ids)).not_to include(list.id)
    end

    it "excludes lists user does not belong to" do
      other_list = create(:list, user: create(:user))

      expect(test_instance.send(:editable_list_ids)).not_to include(other_list.id)
    end

    it "returns empty array when user has no editor memberships" do
      expect(test_instance.send(:editable_list_ids)).to be_empty
    end

    it "memoizes the result" do
      list = create(:list, user: create(:user))
      create(:membership, list: list, user: user, role: "editor")

      first_call = test_instance.send(:editable_list_ids)
      second_call = test_instance.send(:editable_list_ids)

      expect(first_call).to equal(second_call)
    end
  end
end
