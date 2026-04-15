class ChangeExperienceMinToDecimalInJobs < ActiveRecord::Migration[8.1]
  def up
    change_column :jobs, :experience_min, :decimal, precision: 4, scale: 1, using: "experience_min::decimal"
  end

  def down
    change_column :jobs, :experience_min, :integer, using: "ROUND(experience_min)::integer"
  end
end
