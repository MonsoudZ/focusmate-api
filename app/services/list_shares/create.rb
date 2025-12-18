# frozen_string_literal: true

module ListShares
  class Create
    def self.call!(list:, inviter:, params:)
      ListShareCreationService
        .new(list: list, current_user: inviter)
        .create!(
          email: params[:email],
          role: params[:role],
          permissions: params.slice(
            :can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications
          )
        )
    end
  end
end
