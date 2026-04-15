class CreateJobResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :job_resumes do |t|
      t.references :job, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.string :phone
      t.jsonb :skills, default: []
      t.jsonb :education, default: []
      t.jsonb :parsed_data, default: {}
      t.datetime :parsed_at
      t.integer :match_score
      t.jsonb :analysis_json, default: {}
      t.datetime :matched_at

      t.timestamps

      t.index :email
    end
  end
end
