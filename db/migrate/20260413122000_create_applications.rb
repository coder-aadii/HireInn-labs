class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications do |t|
      t.references :job, null: false, foreign_key: true
      t.references :candidate, null: false, foreign_key: true
      t.text :cover_letter
      t.string :status, null: false, default: "submitted"

      t.timestamps

      t.index [:job_id, :candidate_id], unique: true
    end
  end
end
