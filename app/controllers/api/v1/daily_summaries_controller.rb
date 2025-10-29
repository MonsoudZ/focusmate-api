# app/controllers/api/v1/daily_summaries_controller.rb
module Api
  module V1
    class DailySummariesController < ApplicationController
      before_action :set_relationship

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries
      # Query params (optional):
      #   limit: 1..100 (default 30)
      #   before: cursor string "YYYY-MM-DD:ID" for keyset pagination
      #   date_from, date_to: ISO dates to bound the window (inclusive)
      def index
        limit  = [ [ params[:limit].to_i, 1 ].max, 100 ].min rescue 30
        before = params[:before].to_s.presence
        df     = parse_date(params[:date_from])
        dt     = parse_date(params[:date_to])

        scope = @relationship.daily_summaries
                             .includes(:relationship) # preloads minimal assoc if serializer needs it
                             .order(summary_date: :desc, id: :desc)

        scope = scope.where(summary_date: df..Date::Infinity.new) if df
        scope = scope.where(summary_date: Date.new(0)..dt)        if dt

        if before
          bd, bid = decode_cursor(before)
          # keyset: (date,id) <
          scope = scope.where(
            scope.sanitize_sql_array(
              "(summary_date < ? OR (summary_date = ? AND id < ?))", bd, bd, bid
            )
          )
        end

        rows = scope.limit(limit + 1).to_a # overfetch to decide next_cursor
        next_cursor = nil
        if rows.length > limit
          tail = rows[limit - 1]
          next_cursor = encode_cursor(tail.summary_date, tail.id)
          rows = rows.first(limit)
        end

        # Optional caching hint (weak)
        response.set_header("Cache-Control", "private, max-age=60")

        render json: {
          data: rows.map { |s| DailySummarySerializer.new(s).as_json },
          next_cursor: next_cursor
        }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries/:id
      def show
        s = @relationship.daily_summaries.find(params[:id])

        # ETag/conditional GET
        fresh_when(etag: [ s.id, s.updated_at.to_i ], last_modified: s.updated_at, public: false)

        render json: DailySummarySerializer.new(s, detailed: true).as_json, status: :ok
      end

      private

      def set_relationship
        @relationship = CoachingRelationship.find(params[:coaching_relationship_id])
        forbidden!("Forbidden") unless participant?(@relationship, current_user)
        # If you have Pundit, do: authorize @relationship, :show?
      end

      def participant?(rel, user)
        rel.coach_id == user.id || rel.client_id == user.id
      end

      # ---------- errors (uniform) ----------
      def forbidden!(msg)
        render json: { code: "forbidden", message: msg }, status: :forbidden
      end

      # ---------- keyset cursor helpers ----------
      def encode_cursor(date, id)
        # date in YYYY-MM-DD, opaque to clients
        Base64.urlsafe_encode64("#{date.iso8601}:#{id}")
      end

      def decode_cursor(cur)
        raw = Base64.urlsafe_decode64(cur)
        d, i = raw.split(":", 2)
        [ Date.iso8601(d), i ]
      rescue ArgumentError, TypeError
        [ nil, nil ]
      end

      def parse_date(val)
        return nil if val.blank?
        Date.iso8601(val) rescue nil
      end
    end
  end
end
