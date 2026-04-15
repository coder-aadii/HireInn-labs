class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.references :user, null: false, foreign_key: true

      t.string :title, null: false
      t.string :slug, null: false, index: { unique: true }

      t.text :description
      t.text :responsibilities
      t.text :requirements
      t.text :benefits

      t.string :location
      t.string :employment_type # full-time, part-time, contract
      t.integer :experience_min
      t.integer :experience_max

      t.jsonb :skills_required, default: []

      t.integer :salary_min
      t.integer :salary_max
      t.string :currency, default: "INR"

      t.boolean :ai_generated, default: false
      t.jsonb :ai_metadata, default: {}

      t.integer :status, default: 0   # draft, published, archived
      t.datetime :published_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :jobs, :status
    add_index :jobs, :location
    add_index :jobs, :employment_type
    add_index :jobs, :skills_required, using: :gin
  end
end