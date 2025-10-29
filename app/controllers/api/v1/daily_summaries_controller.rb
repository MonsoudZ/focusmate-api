# app/controllers/api/v1/daily_summaries_controller.rb
module Api
  module V1
    class DailySummariesController < ApplicationController
      before_action :set_relationship
      before_action :validate_params, only: [ :index ]

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries
      # Query params (optional):
      #   limit: 1..100 (default 30)
      #   before: cursor string "YYYY-MM-DD:ID" for keyset pagination
      #   date_from, date_to: ISO dates to bound the window (inclusive)
      def index
        limit  = [ [ params[:limit].to_i, 1 ].max, 100 ].min
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
          if bd && bid
            # keyset: (date,id) <
            scope = scope.where(
              scope.sanitize_sql_array(
                "(summary_date < ? OR (summary_date = ? AND id < ?))", bd, bd, bid
              )
            )
          end
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

        # Return array format for backward compatibility with tests
        render json: rows.map { |s| DailySummarySerializer.new(s).as_json }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries/:id
      def show
        s = @relationship.daily_summaries.find(params[:id])

        # ETag/conditional GET
        fresh_when(etag: [ s.id, s.updated_at.to_i ], last_modified: s.updated_at, public: false)

        render json: DailySummarySerializer.new(s, detailed: true).as_json, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "Daily summary not found: #{params[:id]}"
        render json: { error: { message: "Daily summary not found" } },
               status: :not_found
      end

      private

      def set_relationship
        @relationship = CoachingRelationship.find(params[:coaching_relationship_id])
        unless participant?(@relationship, current_user)
          render json: { error: { message: "Unauthorized" } }, status: :forbidden
          nil
        end
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "Coaching relationship not found: #{params[:coaching_relationship_id]}"
        render json: { error: { message: "Coaching relationship not found" } },
               status: :not_found
      end

      def participant?(rel, user)
        rel.coach_id == user.id || rel.client_id == user.id
      end

      def validate_params
        # Validate limit parameter
        if params[:limit].present?
          limit = params[:limit].to_i
          unless limit.between?(1, 100)
            render json: { error: { message: "Limit must be between 1 and 100" } },
                   status: :bad_request
            return
          end
        end

        # Validate date parameters
        if params[:date_from].present?
          unless parse_date(params[:date_from])
            render json: { error: { message: "Invalid date_from format. Use ISO 8601 date format (YYYY-MM-DD)" } },
                   status: :bad_request
            return
          end
        end

        if params[:date_to].present?
          unless parse_date(params[:date_to])
            render json: { error: { message: "Invalid date_to format. Use ISO 8601 date format (YYYY-MM-DD)" } },
                   status: :bad_request
            return
          end
        end

        # Validate cursor parameter
        if params[:before].present?
          unless valid_cursor_format?(params[:before])
            render json: { error: { message: "Invalid cursor format" } },
                   status: :bad_request
            nil
          end
        end
      end

      def valid_cursor_format?(cursor)
        return false if cursor.blank?

        begin
          raw = Base64.urlsafe_decode64(cursor)
          parts = raw.split(":", 2)
          return false unless parts.length == 2

          # Validate date format
          Date.iso8601(parts[0])
          # Validate ID format (should be numeric)
          Integer(parts[1])
          true
        rescue ArgumentError, TypeError
          false
        end
      end

      # ---------- keyset cursor helpers ----------
      def encode_cursor(date, id)
        # date in YYYY-MM-DD, opaque to clients
        Base64.urlsafe_encode64("#{date.iso8601}:#{id}")
      end

      def decode_cursor(cur)
        return [ nil, nil ] if cur.blank?

        begin
          raw = Base64.urlsafe_decode64(cur)
          d, i = raw.split(":", 2)
          return [ nil, nil ] unless d && i

          date = Date.iso8601(d)
          id = Integer(i)
          [ date, id ]
        rescue ArgumentError, TypeError => e
          Rails.logger.warn "Invalid cursor format: #{cur[0..20]}... - #{e.message}"
          [ nil, nil ]
        end
      end

      def parse_date(val)
        return nil if val.blank?

        begin
          Date.iso8601(val)
        rescue ArgumentError => e
          Rails.logger.warn "Invalid date format: #{val} - #{e.message}"
          nil
        end
      end
    end
  end
end
