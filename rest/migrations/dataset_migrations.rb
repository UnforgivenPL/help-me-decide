# frozen_string_literal: true

require 'active_record/migration'

# defines a dataset
# the real dataset is in a file, inside a folder
class CreateDataset < ActiveRecord::Migration[7.0]
  def change
    create_table :dataset_infos do |t|
      t.string :name, :folder, :token
      t.boolean :available, :enabled
      t.integer :requests, default: 0
      t.timestamps
    end
    add_reference :dataset_infos, :user
  end
end

# drops the datasets table
class DropDataset < ActiveRecord::Migration[7.0]
  def change
    drop_table :dataset_infos
  end
end
