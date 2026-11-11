class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.references :parent, foreign_key: { to_table: :categories }
      t.timestamps
    end
  end
end
