# frozen_string_literal: true

namespace :performance do
  desc "Run all performance checks"
  task all: [ :check_indexes, :check_n1_queries, :benchmark_reminder_job ]

  desc "Check for missing indexes on foreign keys and common query patterns"
  task check_indexes: :environment do
    puts "\n=== Checking Database Indexes ==="

    missing_indexes = []

    # Check foreign keys without indexes
    ActiveRecord::Base.connection.tables.each do |table|
      next if table.start_with?("schema_migrations", "ar_internal")

      columns = ActiveRecord::Base.connection.columns(table)
      indexes = ActiveRecord::Base.connection.indexes(table).flat_map(&:columns)

      columns.each do |column|
        next unless column.name.end_with?("_id")
        next if indexes.include?(column.name)

        missing_indexes << { table: table, column: column.name, reason: "Foreign key without index" }
      end
    end

    if missing_indexes.any?
      puts "\n⚠️  Missing indexes found:"
      missing_indexes.each do |mi|
        puts "  - #{mi[:table]}.#{mi[:column]} (#{mi[:reason]})"
      end
    else
      puts "✓ All foreign keys have indexes"
    end

    # Check index usage statistics (PostgreSQL)
    puts "\n=== Index Usage Statistics ==="
    result = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT
        schemaname,
        relname AS table_name,
        indexrelname AS index_name,
        idx_scan AS times_used,
        pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
      FROM pg_stat_user_indexes
      WHERE idx_scan < 10
      ORDER BY pg_relation_size(indexrelid) DESC
      LIMIT 20;
    SQL

    unused_indexes = result.to_a
    if unused_indexes.any?
      puts "\n⚠️  Potentially unused indexes (< 10 scans):"
      unused_indexes.each do |idx|
        puts "  - #{idx['table_name']}.#{idx['index_name']} (used #{idx['times_used']}x, size: #{idx['index_size']})"
      end
    else
      puts "✓ All indexes are being used"
    end

    # Check table sizes
    puts "\n=== Table Sizes ==="
    result = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT
        relname AS table_name,
        n_live_tup AS row_count,
        pg_size_pretty(pg_total_relation_size(relid)) AS total_size
      FROM pg_stat_user_tables
      ORDER BY pg_total_relation_size(relid) DESC
      LIMIT 10;
    SQL

    result.each do |row|
      puts "  #{row['table_name']}: #{row['row_count']} rows (#{row['total_size']})"
    end
  end

  desc "Check for N+1 queries in common endpoints"
  task check_n1_queries: :environment do
    puts "\n=== Checking for N+1 Queries ==="

    require "benchmark"

    # Simulate loading data with query counting
    queries = []
    ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:sql].include?("SCHEMA") || payload[:sql].include?("pg_")
    end

    # Test 1: Loading tasks with lists
    puts "\n--- Test: Loading tasks with associations ---"
    queries.clear
    user = User.first
    if user
      list_ids = user.lists.pluck(:id) + user.memberships.pluck(:list_id)
      tasks = Task.where(list_id: list_ids).includes(:list, :creator, :assigned_to).limit(100).to_a
      tasks.each do |task|
        task.list.name
        task.creator.name
        task.assigned_to&.name
      end
      puts "  Queries executed: #{queries.count}"
      puts "  #{queries.count > 5 ? '⚠️  Potential N+1 detected' : '✓ Looks good'}"
    else
      puts "  Skipped - no users in database"
    end

    # Test 2: Loading list memberships
    puts "\n--- Test: Loading list with memberships ---"
    queries.clear
    list = List.includes(:memberships, :user).first
    if list
      list.memberships.each { |m| m.user.name }
      puts "  Queries executed: #{queries.count}"
      puts "  #{queries.count > 3 ? '⚠️  Potential N+1 detected' : '✓ Looks good'}"
    else
      puts "  Skipped - no lists in database"
    end

    # Test 3: TaskReminderJob query efficiency
    puts "\n--- Test: TaskReminderJob query pattern ---"
    queries.clear
    Task
      .where(status: [ :pending, :in_progress ])
      .where(deleted_at: nil)
      .where(is_template: [ false, nil ])
      .where("due_at IS NOT NULL")
      .where("due_at > ?", Time.current)
      .where("due_at <= ?", 15.minutes.from_now)
      .where(reminder_sent_at: nil)
      .includes(:creator, :assigned_to, :list)
      .limit(100)
      .each do |task|
        (task.assigned_to || task.creator).name
        task.list.name
      end
    puts "  Queries executed: #{queries.count}"
    puts "  #{queries.count > 3 ? '⚠️  Potential N+1 detected' : '✓ Looks good'}"

    ActiveSupport::Notifications.unsubscribe("sql.active_record")
  end

  desc "Benchmark TaskReminderJob with large dataset"
  task benchmark_reminder_job: :environment do
    puts "\n=== Benchmarking TaskReminderJob ==="

    require "benchmark"

    # Count existing data
    task_count = Task.count
    puts "Current task count: #{task_count}"

    if task_count < 100
      puts "⚠️  Not enough data for meaningful benchmark. Creating test data..."

      ActiveRecord::Base.transaction do
        user = User.first || User.create!(
          email: "perf-test@example.com",
          password: "password123",
          name: "Performance Test User"
        )

        list = user.lists.first || user.lists.create!(name: "Performance Test List")

        1000.times do |i|
          Task.create!(
            title: "Performance test task #{i}",
            list: list,
            creator: user,
            status: :pending,
            due_at: rand(1..30).minutes.from_now,
            notification_interval_minutes: 15
          )
        end

        puts "Created 1000 test tasks"
      end
    end

    # Benchmark the job
    puts "\n--- Running benchmark ---"

    # Dry run to warm up
    job = TaskReminderJob.new

    results = Benchmark.bm(20) do |x|
      x.report("find_tasks:") do
        10.times do
          Task
            .where(status: [ :pending, :in_progress ])
            .where(deleted_at: nil)
            .where(is_template: [ false, nil ])
            .where("due_at IS NOT NULL")
            .where("due_at > ?", Time.current)
            .where("due_at <= ?", 15.minutes.from_now)
            .where(reminder_sent_at: nil)
            .includes(:creator, :assigned_to)
            .to_a
        end
      end

      x.report("full_job (mocked):") do
        allow_any_instance_of(PushNotifications::Sender).to receive(:send_to_user) if defined?(RSpec)
        # Just test the query portion, not actual notifications
        5.times do
          Task
            .where(status: [ :pending, :in_progress ])
            .where(deleted_at: nil)
            .where(is_template: [ false, nil ])
            .where("due_at IS NOT NULL")
            .where("due_at > ?", Time.current)
            .where("due_at <= ?", 15.minutes.from_now)
            .where(reminder_sent_at: nil)
            .includes(:creator, :assigned_to)
            .find_each(batch_size: 100) do |task|
              # Simulate notification building
              task.assigned_to || task.creator
              task.title
            end
        end
      end
    end

    # Query plan analysis
    puts "\n--- Query Plan Analysis ---"
    plan = ActiveRecord::Base.connection.execute(<<-SQL)
      EXPLAIN ANALYZE
      SELECT tasks.*
      FROM tasks
      WHERE status IN (0, 1)
        AND deleted_at IS NULL
        AND (is_template = false OR is_template IS NULL)
        AND due_at IS NOT NULL
        AND due_at > NOW()
        AND due_at <= NOW() + INTERVAL '15 minutes'
        AND reminder_sent_at IS NULL
      LIMIT 100;
    SQL

    plan.each { |row| puts "  #{row['QUERY PLAN']}" }
  end

  desc "Generate load test script for API endpoints"
  task generate_load_test: :environment do
    script_path = Rails.root.join("script", "load_test.sh")

    content = <<~BASH
      #!/bin/bash
      # API Load Testing Script
      # Usage: ./script/load_test.sh [base_url] [token]

      BASE_URL="${1:-http://localhost:3000}"
      TOKEN="${2:-your_jwt_token_here}"

      echo "=== API Load Testing ==="
      echo "Base URL: $BASE_URL"
      echo ""

      # Test configuration
      REQUESTS=100
      CONCURRENCY=10

      run_test() {
        local name="$1"
        local endpoint="$2"
        local method="${3:-GET}"

        echo "--- Testing: $name ($method $endpoint) ---"
        if [ "$method" = "GET" ]; then
          ab -n $REQUESTS -c $CONCURRENCY -H "Authorization: Bearer $TOKEN" "$BASE_URL$endpoint" 2>&1 | grep -E "(Requests per second|Time per request|Failed requests)"
        fi
        echo ""
      }

      # Public endpoints (no auth)
      echo "=== Public Endpoints ==="
      ab -n $REQUESTS -c $CONCURRENCY "$BASE_URL/health" 2>&1 | grep -E "(Requests per second|Time per request|Failed requests)"
      echo ""

      # Authenticated endpoints
      echo "=== Authenticated Endpoints ==="
      run_test "List tasks" "/api/v1/lists/1/tasks"
      run_test "Get lists" "/api/v1/lists"
      run_test "Get friends" "/api/v1/friends"
      run_test "Today's tasks" "/api/v1/tasks/today"

      echo "=== Load Test Complete ==="
    BASH

    FileUtils.mkdir_p(Rails.root.join("script"))
    File.write(script_path, content)
    File.chmod(0o755, script_path)

    puts "Generated load test script: #{script_path}"
    puts "\nUsage:"
    puts "  ./script/load_test.sh http://localhost:3000 YOUR_JWT_TOKEN"
  end

  desc "Analyze slow queries from PostgreSQL logs"
  task analyze_slow_queries: :environment do
    puts "\n=== Slow Query Analysis ==="

    # Check pg_stat_statements if available
    begin
      result = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT
          substring(query, 1, 100) AS query_preview,
          calls,
          round(total_exec_time::numeric, 2) AS total_ms,
          round(mean_exec_time::numeric, 2) AS avg_ms,
          round(max_exec_time::numeric, 2) AS max_ms,
          rows
        FROM pg_stat_statements
        WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user)
        ORDER BY total_exec_time DESC
        LIMIT 20;
      SQL

      if result.any?
        puts "\nTop 20 slowest queries (by total time):"
        result.each_with_index do |row, i|
          puts "\n#{i + 1}. #{row['query_preview']}..."
          puts "   Calls: #{row['calls']}, Total: #{row['total_ms']}ms, Avg: #{row['avg_ms']}ms, Max: #{row['max_ms']}ms"
        end
      end
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("pg_stat_statements")
        puts "pg_stat_statements extension not enabled."
        puts "Enable it with: CREATE EXTENSION pg_stat_statements;"
      else
        raise
      end
    end
  end
end
