# frozen_string_literal: true

class TagSerializer
  def initialize(tag)
    @tag = tag
  end

  def as_json
    {
      id: @tag.id,
      name: @tag.name,
      color: @tag.color,
      tasks_count: @tag.tasks.count,
      created_at: @tag.created_at.iso8601
    }
  end
end
