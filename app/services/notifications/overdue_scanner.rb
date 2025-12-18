# frozen_string_literal: true

module Notifications
  class OverdueScanner
    LOCK_TTL_SECONDS = 60

    def self.call!(since_minutes:, batch_size:)
      new(since_minutes:, batch_size:).call!
    end

    def initialize(since_minutes:, batch_size:)
      @since_minutes = since_minutes.to_i
      @batch_size = batch_size.to_i
      @lock_key = "#{Rails.env}:overdue_scan_lock"
      @lock_token = SecureRandom.uuid
    end

    def call!
      start = Time.current
      Rails.logger.info("[OverdueScan] start since_minutes=#{@since_minutes} batch_size=#{@batch_size}")

      acquired = with_redis_lock(@lock_key, token: @lock_token, ttl: LOCK_TTL_SECONDS) do
        enqueue_overdue_tasks
      end

      unless acquired
        Rails.logger.warn("[OverdueScan] skipped (lock held)")
        return
      end

      ms = ((Time.current - start) * 1000).round(2)
      Rails.logger.info("[OverdueScan] done duration_ms=#{ms}")
    end

    private

    def enqueue_overdue_tasks
      cutoff = @since_minutes.minutes.ago

      scope = Task.where(status: "pending", completed_at: nil)
                  .where.not(due_at: nil)
                  .where("due_at < ?", cutoff)

      total = 0

      scope.in_batches(of: @batch_size) do |relation|
        ids = relation.pluck(:id)
        next if ids.empty?

        Sidekiq::Client.push_bulk(
          "class" => NudgeJob,
          "queue" => "notifications",
          "args" => ids.map { |id| [ id, nil, { "priority" => "high", "skip_creator" => true } ] }
        )

        total += ids.length
        Rails.logger.info("[OverdueScan] enqueued=#{ids.length} total=#{total}")
      end

      Rails.logger.info("[OverdueScan] finished total=#{total}")
    end

    # Safe-ish lock:
    # - uses unique token
    # - releases only if token matches
    # - best-effort
    def with_redis_lock(key, token:, ttl:)
      return yield_and_true unless Sidekiq.respond_to?(:redis)

      acquired = false

      Sidekiq.redis do |conn|
        acquired = conn.set(key, token, nx: true, ex: ttl)

        return false unless acquired

        begin
          yield
        ensure
          begin
            current = conn.get(key)
            conn.del(key) if current.to_s == token.to_s
          rescue
            # best-effort unlock; ignore
          end
        end
      end

      true
    rescue => e
      Rails.logger.error("[OverdueScan] lock_error #{e.class}: #{e.message}")
      # If lock infra fails, it's safer to NOT enqueue than to spam.
      false
    end

    def yield_and_true
      yield
      true
    end
  end
end
