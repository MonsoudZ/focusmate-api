class DropFlipperTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :flipper_gates, if_exists: true
    drop_table :flipper_features, if_exists: true
  end

  def down
    create_table :flipper_features do |t|
      t.string :key, null: false
      t.timestamps null: false
      t.index :key, unique: true
    end

    create_table :flipper_gates do |t|
      t.string :feature_key, null: false
      t.string :key, null: false
      t.text :value
      t.timestamps null: false
      t.index [ :feature_key, :key, :value ], unique: true, name: "index_flipper_gates_on_feature_key_and_key_and_value"
    end
  end
end
