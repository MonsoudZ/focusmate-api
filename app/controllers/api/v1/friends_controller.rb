# frozen_string_literal: true

module Api
  module V1
    class FriendsController < BaseController
      # GET /api/v1/friends
      def index
        friends = current_user.friends.order(:name)

        render json: {
          friends: friends.map { |f| FriendSerializer.new(f).as_json }
        }, status: :ok
      end

      # DELETE /api/v1/friends/:id
      def destroy
        friend = User.find(params[:id])

        unless Friendship.friends?(current_user, friend)
          return render json: { error: { message: "Not friends with this user" } }, status: :not_found
        end

        Friendship.destroy_mutual!(current_user, friend)

        head :no_content
      end
    end
  end
end
