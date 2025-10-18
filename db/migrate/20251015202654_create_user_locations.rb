class CreateUserLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_locations do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.decimal :accuracy, precision: 10, scale: 2
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :user_locations, :recorded_at
  end
end
