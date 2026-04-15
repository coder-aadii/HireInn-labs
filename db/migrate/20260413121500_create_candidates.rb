class CreateCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :candidates do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone

      t.timestamps

      t.index :email, unique: true
    end
  end
end
