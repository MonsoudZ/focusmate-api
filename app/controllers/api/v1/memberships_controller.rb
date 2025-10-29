# frozen_string_literal: true

module Api
  module V1
    class MembershipsController < ApplicationController
      include Pundit::Authorization
      before_action :authenticate_user!
      before_action :set_list
      before_action :set_membership, only: [ :show, :update, :destroy ]
      after_action :verify_authorized, except: [ :index, :create ]
      after_action :verify_policy_scoped, only: [ :index ]

      # GET /api/v1/lists/:list_id/memberships
      def index
        @memberships = policy_scope(@list.memberships).includes(:user)
        authorize @list, :show?

        render json: {
          memberships: @memberships.map do |membership|
            {
              id: membership.id,
              user: {
                id: membership.user.id,
                email: membership.user.email
              },
              role: membership.role,
              created_at: membership.created_at,
              updated_at: membership.updated_at
            }
          end
        }
      end

      # GET /api/v1/lists/:list_id/memberships/:id
      def show
        authorize @membership
        render json: {
          membership: {
            id: @membership.id,
            user: {
              id: @membership.user.id,
              email: @membership.user.email
            },
            role: @membership.role,
            created_at: @membership.created_at,
            updated_at: @membership.updated_at
          }
        }
      end

      # POST /api/v1/lists/:list_id/memberships
      def create
        # Find user by email or ID
        target_user = find_user_by_email_or_id(membership_params[:user_identifier])

        unless target_user
          return render json: { error: "User not found" }, status: :not_found
        end

        # Check if user is already a member
        if @list.members.include?(target_user)
          return render json: { error: "User is already a member of this list" }, status: :unprocessable_entity
        end

        # Check if user is trying to invite themselves
        if target_user == current_user
          return render json: { error: "Cannot invite yourself" }, status: :unprocessable_entity
        end

        @membership = @list.memberships.build(
          user: target_user,
          role: membership_params[:role] || "viewer"
        )

        authorize @membership

        if @membership.save
          render json: {
            membership: {
              id: @membership.id,
              user: {
                id: @membership.user.id,
                email: @membership.user.email
              },
              role: @membership.role,
              created_at: @membership.created_at,
              updated_at: @membership.updated_at
            }
          }, status: :created
        else
          render json: { errors: @membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/lists/:list_id/memberships/:id
      def update
        authorize @membership

        if @membership.update(membership_params.except(:user_identifier))
          render json: {
            membership: {
              id: @membership.id,
              user: {
                id: @membership.user.id,
                email: @membership.user.email
              },
              role: @membership.role,
              created_at: @membership.created_at,
              updated_at: @membership.updated_at
            }
          }
        else
          render json: { errors: @membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/lists/:list_id/memberships/:id
      def destroy
        authorize @membership
        @membership.destroy
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:list_id])
        authorize @list, :show?
      end

      def set_membership
        @membership = @list.memberships.find(params[:id])
      end

      def membership_params
        # Only permit user_identifier, handle role separately for security
        permitted = params.require(:membership).permit(:user_identifier)

        # Handle role separately with explicit validation
        if params[:membership][:role].present?
          role = params[:membership][:role].to_s.downcase
          if %w[editor viewer].include?(role)
            permitted[:role] = role
          else
            permitted[:role] = "viewer" # Default to viewer for invalid roles
          end
        else
          permitted[:role] = "viewer" # Default role
        end

        permitted
      end

      def find_user_by_email_or_id(identifier)
        # Try to find by ID first (if it's a number)
        if identifier.match?(/^\d+$/)
          User.find_by(id: identifier)
        else
          # Otherwise, try to find by email
          User.find_by(email: identifier)
        end
      end
    end
  end
end
