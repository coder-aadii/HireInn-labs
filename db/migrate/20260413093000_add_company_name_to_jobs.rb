class AddCompanyNameToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :company_name, :string
    remove_column :jobs, :experience_max, :integer
  end
end
