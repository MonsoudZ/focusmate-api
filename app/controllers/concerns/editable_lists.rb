# frozen_string_literal: true

module EditableLists
  extend ActiveSupport::Concern

  private

  def editable_list_ids
    @editable_list_ids ||= Membership.where(user_id: current_user.id, role: "editor").pluck(:list_id)
  end
end
