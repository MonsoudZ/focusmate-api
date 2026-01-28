class DropUnusedTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :notification_logs, if_exists: true
    drop_table :saved_locations, if_exists: true
    drop_table :user_locations, if_exists: true

    safety_assured { remove_column :users, :notification_logs_count, if_exists: true }
  end

  def down
    create_table :notification_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.string :notification_type, null: false
      t.string :delivery_method
      t.boolean :delivered, default: false, null: false
      t.jsonb :metadata, default: {}
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :saved_locations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.decimal :radius, precision: 10, scale: 2
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :user_locations do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.decimal :accuracy, precision: 10, scale: 2
      t.datetime :recorded_at
      t.string :source
      t.jsonb :metadata, default: {}
      t.datetime :deleted_at
      t.timestamps
    end

    add_column :users, :notification_logs_count, :integer, default: 0, null: false
  end
end
