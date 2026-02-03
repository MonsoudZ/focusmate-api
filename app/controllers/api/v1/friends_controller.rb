# frozen_string_literal: true

module Api
  module V1
    class FriendsController < BaseController
      include Paginatable

      # GET /api/v1/friends
      # Optional param: exclude_list_id - filters out friends who are already members of that list
      def index
        friends = current_user.friends.order(:name)

        # Filter out friends who are already members of a specific list
        if params[:exclude_list_id].present?
          list = List.find_by(id: params[:exclude_list_id])
          if list && list.accessible_by?(current_user)
            # Get all member IDs (including owner)
            existing_member_ids = list.memberships.pluck(:user_id) + [ list.user_id ]
            friends = friends.where.not(id: existing_member_ids)
          end
        end

        result = paginate(
          friends,
          page: params[:page],
          per_page: params[:per_page],
          default_per_page: 50,
          max_per_page: 100
        )
        pagination = result[:pagination]

        render json: {
          friends: result[:records].map { |f| FriendSerializer.new(f).as_json },
          pagination: {
            page: pagination[:page],
            per_page: pagination[:per_page],
            total_count: pagination[:total],
            total_pages: pagination[:total_pages]
          }
        }, status: :ok
      end

      # DELETE /api/v1/friends/:id
      def destroy
        friend = User.find(params[:id])

        unless Friendship.friends?(current_user, friend)
          return render_error("Not friends with this user", status: :not_found, code: "not_friends")
        end

        Friendship.destroy_mutual!(current_user, friend)

        head :no_content
      end
    end
  end
end
