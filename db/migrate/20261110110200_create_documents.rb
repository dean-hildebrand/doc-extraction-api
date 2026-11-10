class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true, index: false
      t.references :api_key, type: :uuid, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.string :checksum_sha256, null: false
      t.integer :page_count
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :documents, [ :organization_id, :created_at ]
    add_index :documents, [ :organization_id, :checksum_sha256 ]
  end
end
