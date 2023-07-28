# frozen_string_literal: true

require 'active_record/migration'

# defines a dataset
# the real dataset is in a file, inside a folder
class CreateLogEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :log_entries do |t|
      t.string :session, :operation, :dataset_id, :strategy, :question, :answers
      t.timestamps
    end
  end
end

# drops the datasets table
class DropLogEntries < ActiveRecord::Migration[7.0]
  def change
    drop_table :log_entries
  end
end
