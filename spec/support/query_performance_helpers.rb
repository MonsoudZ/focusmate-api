# frozen_string_literal: true

module QueryPerformanceHelpers
  def collect_queries
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if sql.include?("SCHEMA")
      next if sql.start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE SAVEPOINT")

      queries << sql
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    queries
  end

  def table_select_count(queries, table_name)
    queries.count { |sql| sql.start_with?("SELECT") && sql.include?("FROM \"#{table_name}\"") }
  end

  def table_query_count(queries, table_name)
    queries.count { |sql| sql.include?("\"#{table_name}\"") }
  end

  def select_count(queries)
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
