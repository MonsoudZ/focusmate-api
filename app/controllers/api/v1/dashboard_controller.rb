# frozen_string_literal: true

module Api
  module V1
    class DashboardController < ApplicationController
      # GET /api/v1/dashboard
      # Params:
      #   from, to: ISO8601 dates/times (optional)
      #   tz: IANA TZ (defaults to current_user.timezone or "UTC")
      #   sections: comma list to limit payload (e.g., "inbox,velocity,streaks")
      def show
        window = extract_window(params, current_user)
        sections = parse_sections(params[:sections])

        data = DashboardDataService.new(user: current_user, window:, sections:).call

        # ETag/Last-Modified for cheap conditional GETs
        etag = [ "dash-show", current_user.id, data[:digest], window[:from]&.to_i, window[:to]&.to_i, sections.sort ].join(":")
        fresh_when etag:, last_modified: data[:last_modified] || Time.current, public: false

        # Small private cache; iOS will still revalidate via ETag
        response.set_header("Cache-Control", "private, max-age=60")

        render json: data, status: :ok
      rescue DashboardDataService::ValidationError => e
        render json: { code: "validation_error", message: "Invalid parameters", details: e.details }, status: :unprocessable_entity
      rescue DashboardDataService::TooExpensiveError
        render json: { code: "timeout", message: "Dashboard query took too long" }, status: :request_timeout
      end

      # GET /api/v1/dashboard/stats
      # Params:
      #   from, to, tz (same as above)
      #   group_by: "day" | "week" | "month" (default: "day")
      #   limit: integer (default 30, max 365)
      def stats
        window = extract_window(params, current_user)
        group_by = %w[day week month].include?(params[:group_by]) ? params[:group_by] : "day"
        limit = [ [ params[:limit].to_i, 1 ].max, 365 ].min rescue 30

        stats = DashboardDataService.new(user: current_user, window:).stats(group_by:, limit:)

        etag = [ "dash-stats", current_user.id, stats[:digest], window[:from]&.to_i, window[:to]&.to_i, group_by, limit ].join(":")
        fresh_when etag:, last_modified: stats[:last_modified] || Time.current, public: false
        response.set_header("Cache-Control", "private, max-age=60")

        render json: stats, status: :ok
      rescue DashboardDataService::ValidationError => e
        render json: { code: "validation_error", message: "Invalid parameters", details: e.details }, status: :unprocessable_entity
      end

      private

      # from/to can be date or datetime; coerce to Time in the user's TZ and clamp to sane bounds.
      def extract_window(p, user)
        tz = p[:tz].presence || user&.timezone.presence || "UTC"
        Time.use_zone(tz) do
          from = parse_time(p[:from]) || 30.days.ago
          to   = parse_time(p[:to])   || Time.zone.now
          # Ensure from <= to and bound range to 400 days to prevent runaway queries
          if from > to
            from, to = to, from
          end
          if (to - from) > 400.days
            from = to - 400.days
          end
          { from:, to:, tz: }
        end
      rescue ArgumentError
        raise DashboardDataService::ValidationError.new(details: { tz: [ "invalid timezone" ] })
      end

      def parse_time(val)
        return nil if val.blank?
        Time.zone.iso8601(val) rescue Time.zone.parse(val) rescue nil
      end

      def parse_sections(raw)
        return [] if raw.blank?
        raw.to_s.split(",").map!(&:strip).reject!(&:blank?) || []
      end
    end
  end
end
