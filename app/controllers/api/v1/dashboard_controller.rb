# frozen_string_literal: true

module Api
  module V1
    class DashboardController < ApplicationController
      before_action :authenticate_user!

      # Centralize "allowed" inputs so the controller is auditable.
      ALLOWED_SECTIONS = %w[
        inbox
        velocity
        streaks
        tasks
        focus
        reminders
        habits
        insights
      ].freeze

      ALLOWED_GROUP_BY = %w[day week month].freeze

      # GET /api/v1/dashboard
      # Params:
      #   from, to: ISO8601 dates/times (optional)
      #   tz: IANA TZ (defaults to current_user.timezone or "UTC")
      #   sections: comma list to limit payload (e.g., "inbox,velocity,streaks")
      def show
        window   = extract_window(params, current_user)
        sections = parse_sections(params[:sections])

        data = DashboardDataService.new(user: current_user, window: window, sections: sections).call

        etag = [
          "dash-show",
          current_user.id,
          data[:digest],
          window[:from]&.to_i,
          window[:to]&.to_i,
          sections.sort
        ].join(":")

        fresh_when etag: etag, last_modified: (data[:last_modified] || Time.current), public: false
        response.set_header("Cache-Control", "private, max-age=60")

        render json: data, status: :ok
      rescue DashboardDataService::ValidationError => e
        render json: { code: "validation_error", message: "Invalid parameters", details: e.details },
               status: :unprocessable_content
      rescue DashboardDataService::TooExpensiveError
        render json: { code: "timeout", message: "Dashboard query took too long" }, status: :request_timeout
      end

      # GET /api/v1/dashboard/stats
      # Params:
      #   from, to, tz (same as above)
      #   group_by: "day" | "week" | "month" (default: "day")
      #   limit: integer (default 30, max 365)
      def stats
        window   = extract_window(params, current_user)
        group_by = parse_group_by(params[:group_by])
        limit    = parse_limit(params[:limit])

        stats = DashboardDataService.new(user: current_user, window: window).stats(group_by: group_by, limit: limit)

        etag = [
          "dash-stats",
          current_user.id,
          stats[:digest],
          window[:from]&.to_i,
          window[:to]&.to_i,
          group_by,
          limit
        ].join(":")

        fresh_when etag: etag, last_modified: (stats[:last_modified] || Time.current), public: false
        response.set_header("Cache-Control", "private, max-age=60")

        render json: stats, status: :ok
      rescue DashboardDataService::ValidationError => e
        render json: { code: "validation_error", message: "Invalid parameters", details: e.details },
               status: :unprocessable_content
      end

      private

      # from/to can be date or datetime; coerce to Time in the user's TZ and clamp to sane bounds.
      def extract_window(p, user)
        tz = p[:tz].presence || user&.timezone.presence || "UTC"

        Time.use_zone(tz) do
          from = parse_time(p[:from]) || 30.days.ago.in_time_zone(Time.zone)
          to   = parse_time(p[:to])   || Time.zone.now

          # Ensure from <= to and bound range to 400 days to prevent runaway queries
          if from > to
            from, to = to, from
          end

          if (to - from) > 400.days
            from = to - 400.days
          end

          { from: from, to: to, tz: tz }
        end
      rescue ArgumentError
        raise DashboardDataService::ValidationError.new(details: { tz: ["invalid timezone"] })
      end

      def parse_time(val)
        return nil if val.blank?

        # Prefer strict ISO8601 if provided; fall back to zone parsing.
        t = Time.iso8601(val)
        t.in_time_zone(Time.zone)
      rescue ArgumentError, TypeError
        begin
          t = Time.zone.parse(val.to_s)
          t&.in_time_zone(Time.zone)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def parse_sections(raw)
        return [] if raw.blank?

        requested = raw.to_s.split(",").map { |s| s.strip.downcase }.reject(&:blank?).uniq

        unknown = requested - ALLOWED_SECTIONS
        if unknown.any?
          raise DashboardDataService::ValidationError.new(
            details: { sections: ["unknown sections: #{unknown.join(', ')}"] }
          )
        end

        requested
      end

      def parse_group_by(raw)
        val = raw.to_s.strip.downcase
        return "day" if val.blank?
        return val if ALLOWED_GROUP_BY.include?(val)

        raise DashboardDataService::ValidationError.new(details: { group_by: ["must be one of: #{ALLOWED_GROUP_BY.join(', ')}"] })
      end

      def parse_limit(raw)
        limit = raw.to_i
        limit = 30 if limit <= 0
        [[limit, 1].max, 365].min
      end
    end
  end
end
