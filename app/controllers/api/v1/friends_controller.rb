# frozen_string_literal: true

module Api
  module V1
    class FriendsController < BaseController
      # GET /api/v1/friends
      # Optional param: exclude_list_id - filters out friends who are already members of that list
      def index
        page = (params[:page] || 1).to_i
        per_page = [ (params[:per_page] || 50).to_i, 100 ].min

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

        total_count = friends.count
        paginated_friends = friends.offset((page - 1) * per_page).limit(per_page)

        render json: {
          friends: paginated_friends.map { |f| FriendSerializer.new(f).as_json },
          pagination: {
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
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
