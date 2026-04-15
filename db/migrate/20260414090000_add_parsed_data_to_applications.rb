class AddParsedDataToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :parsed_data, :jsonb, default: {}, null: false
    add_column :applications, :parsed_at, :datetime
  end
end
