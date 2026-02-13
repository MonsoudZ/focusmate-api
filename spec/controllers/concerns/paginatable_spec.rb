# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paginatable do
  let(:test_class) do
    Class.new do
      include Paginatable
    end
  end

  let(:instance) { test_class.new }

  describe "#order" do
    let(:user) { create(:user) }
    let(:list) { create(:list, user: user) }
    let(:query) { Task.where(list_id: list.id) }

    it "applies valid column and direction" do
      result = instance.order(
        query,
        order_by: "due_at",
        order_direction: "asc",
        valid_columns: %w[created_at due_at title]
      )

      expect(result.to_sql).to include("due_at")
      expect(result.to_sql).to include("ASC")
    end

    it "falls back to default column for invalid column" do
      result = instance.order(
        query,
        order_by: "injected_column",
        order_direction: "asc",
        valid_columns: %w[created_at due_at title]
      )

      expect(result.to_sql).to include("created_at")
    end

    it "falls back to default direction for invalid direction" do
      result = instance.order(
        query,
        order_by: "created_at",
        order_direction: "invalid",
        valid_columns: %w[created_at due_at title]
      )

      expect(result.to_sql).to include("DESC")
    end

    it "accepts valid lowercase direction" do
      result = instance.order(
        query,
        order_by: "title",
        order_direction: "desc",
        valid_columns: %w[created_at due_at title]
      )

      expect(result.to_sql).to include("title")
      expect(result.to_sql).to include("DESC")
    end
  end
end
