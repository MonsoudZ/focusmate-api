class OverdueScanJob
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 2, backtrace: true

  # Scan for overdue, still-pending tasks and enqueue nudges.
  # since_minutes: how far back to consider tasks overdue (default: 10 minutes)
  # batch_size:    how many task IDs to enqueue per Sidekiq bulk push
  def perform(since_minutes = 10, batch_size: 1_000)
    start_time = Time.current
    job_id = jid || SecureRandom.uuid

    Rails.logger.info "[OverdueScanJob] Starting job #{job_id} (since_minutes=#{since_minutes}, batch_size=#{batch_size})"

    # Prevent overlapping scans (best-effort lock for a short window)
    lock_key = "overdue_scan_lock"
    acquired_lock = with_redis_lock(lock_key, ttl: 60) do
      enqueue_overdue_tasks(since_minutes: since_minutes, batch_size: batch_size)
    end

    unless acquired_lock
      Rails.logger.warn "[OverdueScanJob] Another scan appears to be running. Skipping this execution."
      return
    end

    duration = ((Time.current - start_time) * 1000).round(2)
    Rails.logger.info "[OverdueScanJob] Completed job #{job_id} in #{duration}ms"
  rescue => e
    Rails.logger.error "[OverdueScanJob] Job failed: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise e
  end

  private

  def enqueue_overdue_tasks(since_minutes:, batch_size:)
    cutoff_time = since_minutes.to_i.minutes.ago

    scope = Task.where(status: "pending")
                .where.not(due_at: nil)
                .where("due_at < ?", cutoff_time)
                .where(completed_at: nil)

    total = 0

    # Iterate IDs to keep memory bounded
    scope.in_batches(of: batch_size) do |relation|
      ids = relation.pluck(:id)
      next if ids.empty?

      Sidekiq::Client.push_bulk(
        'class' => NudgeJob,
        'args'  => ids.map { |id| [id, nil, { priority: 'high', skip_creator: true }] },
        'queue' => :notifications
      )

      total += ids.length
      Rails.logger.info "[OverdueScanJob] Enqueued #{ids.length} nudges (total=#{total})"
    end

    Rails.logger.info "[OverdueScanJob] Finished enqueuing #{total} overdue tasks"
  end

  # Best-effort Redis lock using Sidekiq's Redis connection
  def with_redis_lock(key, ttl: 60)
    acquired = false
    if defined?(Sidekiq) && Sidekiq.respond_to?(:redis)
      Sidekiq.redis do |conn|
        # SET key value NX EX ttl
        acquired = conn.set(key, Process.pid, nx: true, ex: ttl)
        if acquired
          begin
            yield
          ensure
            # Release only if we still own it
            begin
              current = conn.get(key)
              conn.del(key) if current.to_s == Process.pid.to_s
            rescue
              # ignore
            end
          end
        end
      end
    else
      # If Sidekiq.redis is unavailable, proceed without a lock
      yield
      acquired = true
    end
    acquired ? true : false
  end
end
