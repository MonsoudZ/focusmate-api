# frozen_string_literal: true

module Api
  module V1
    class FriendsController < BaseController
      include Paginatable

      # GET /api/v1/friends
      # Optional param: exclude_list_id - filters out friends who are already members of that list
      def index
        friends = current_user.friends.order(:name)
        query = friends_query_params

        # Filter out friends who are already members of a specific list
        if query[:exclude_list_id].present?
          list_id = parse_positive_integer(query[:exclude_list_id])
          list = List.find_by(id: list_id) if list_id
          if list && list.accessible_by?(current_user)
            member_ids = list.memberships.select(:user_id)
            friends = friends.where.not(id: member_ids).where.not(id: list.user_id)
          end
        end

        result = paginate(
          friends,
          page: query[:page],
          per_page: query[:per_page],
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
        friend = current_user.friends.find_by(id: params[:id])

        unless friend
          return render_error("Not friends with this user", status: :not_found, code: "not_found")
        end

        Friendship.destroy_mutual!(current_user, friend)

        head :no_content
      end

      private

      def friends_query_params
        params.permit(:exclude_list_id, :page, :per_page)
      end

      def parse_positive_integer(value)
        parsed = Integer(value, exception: false)
        return nil if parsed.nil? || parsed <= 0

        parsed
      end
    end
  end
end
