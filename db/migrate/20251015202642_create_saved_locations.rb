class CreateSavedLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_locations do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.integer :radius_meters, default: 100
      t.string :address
      
      t.timestamps
    end
  end
end