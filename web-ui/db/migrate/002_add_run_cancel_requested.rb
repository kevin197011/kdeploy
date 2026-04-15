# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:runs) do
      add_column :cancel_requested, TrueClass, null: false, default: false
    end
  end
end
