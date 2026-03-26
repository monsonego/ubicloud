# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:postgres_log_destination) do
      column :id, :uuid, primary_key: true
      foreign_key :postgres_resource_id, :postgres_resource, type: :uuid, null: false
      column :name, :text, null: false
      column :host, :text, null: false
      column :port, :integer, null: false
      column :structured_data, :text
    end
  end
end
