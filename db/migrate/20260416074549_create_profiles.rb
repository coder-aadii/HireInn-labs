class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.string :first_name, null: false
      t.string :last_name
      t.string :phone
      t.string :designation
      t.string :company_name
      t.string :company_location
      t.string :avatar_url
      t.text :bio
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :profiles, :phone
  end
end