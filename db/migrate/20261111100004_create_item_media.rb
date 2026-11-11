class CreateItemMedia < ActiveRecord::Migration[8.1]
  def change
    # The file itself is an Active Storage attachment, so there is no `url` column.
    create_table :item_media do |t|
      t.references :item, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
    add_index :item_media, [ :item_id, :kind, :sort_order ]
    add_check_constraint :item_media, "kind IN ('image', 'video', 'document')", name: "item_media_kind_valid"
  end
end
