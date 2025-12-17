# frozen_string_literal: true

module Api
  module V1
    class DailySummariesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_relationship
      before_action :validate_params, only: :index

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries
      #
      # Optional query params:
      #   limit      (1..100, default 30)
      #   before     opaque cursor "YYYY-MM-DD:ID" (Base64)
      #   date_from  ISO8601 date (inclusive)
      #   date_to    ISO8601 date (inclusive)
      #
      def index
        limit  = normalized_limit
        before = params[:before].presence
        df     = parse_date(params[:date_from])
        dt     = parse_date(params[:date_to])

        scope = @relationship.daily_summaries
                             .order(summary_date: :desc, id: :desc)

        scope = scope.where(summary_date: df..) if df
        scope = scope.where(summary_date: ..dt) if dt

        if before
          bd, bid = decode_cursor(before)
          if bd && bid
            scope = scope.where(
              "(summary_date < ?) OR (summary_date = ? AND id < ?)",
              bd, bd, bid
            )
          end
        end

        rows = scope.limit(limit + 1).to_a

        next_cursor = nil
        if rows.length > limit
          tail = rows[limit - 1]
          next_cursor = encode_cursor(tail.summary_date, tail.id)
          rows = rows.first(limit)
        end

        response.set_header("Cache-Control", "private, max-age=60")

        render json: {
          data: rows.map { |s| DailySummarySerializer.new(s).as_json },
          next_cursor: next_cursor
        }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries/:id
      def show
        summary = @relationship.daily_summaries.find(params[:id])

        fresh_when(
          etag: [summary.id, summary.updated_at.to_i],
          last_modified: summary.updated_at,
          public: false
        )

        render json: DailySummarySerializer.new(summary, detailed: true).as_json,
               status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: { message: "Daily summary not found" } },
               status: :not_found
      end

      private

      # ---------- Authorization ----------

      def set_relationship
        @relationship = CoachingRelationship.find(params[:coaching_relationship_id])

        unless participant?(@relationship, current_user)
          render json: { error: { message: "Forbidden" } }, status: :forbidden
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: { message: "Coaching relationship not found" } },
               status: :not_found
      end

      def participant?(rel, user)
        rel.coach_id == user.id || rel.client_id == user.id
      end

      # ---------- Validation ----------

      def validate_params
        validate_limit!
        validate_date!(:date_from)
        validate_date!(:date_to)
        validate_cursor!
      end

      def validate_limit!
        return unless params[:limit].present?

        unless params[:limit].to_i.between?(1, 100)
          render json: { error: { message: "limit must be between 1 and 100" } },
                 status: :bad_request
        end
      end

      def validate_date!(key)
        return unless params[key].present?

        unless parse_date(params[key])
          render json: {
            error: { message: "Invalid #{key}. Use YYYY-MM-DD." }
          }, status: :bad_request
        end
      end

      def validate_cursor!
        return unless params[:before].present?

        decode_cursor(params[:before]) || render(
          json: { error: { message: "Invalid cursor format" } },
          status: :bad_request
        )
      end

      # ---------- Pagination helpers ----------

      def normalized_limit
        params[:limit].present? ? params[:limit].to_i.clamp(1, 100) : 30
      end

      def encode_cursor(date, id)
        Base64.urlsafe_encode64("#{date.iso8601}:#{id}")
      end

      def decode_cursor(cursor)
        raw = Base64.urlsafe_decode64(cursor)
        d, i = raw.split(":", 2)
        [Date.iso8601(d), Integer(i)]
      rescue ArgumentError, TypeError
        nil
      end

      # ---------- Utilities ----------

      def parse_date(val)
        Date.iso8601(val) if val.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
