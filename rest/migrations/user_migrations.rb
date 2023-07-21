# frozen_string_literal: true
require 'active_record/migration'

# creates users table
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :name, :pass, :email, :token
      t.boolean :verified, :active
      t.integer :tier, default: 0
      t.integer :dataset_quota, default: 5
      t.integer :request_quota, default: 1000
      t.timestamps
    end
  end
end

# drops users table
class DropUsers < ActiveRecord::Migration[7.0]
  def change
    drop_table :users
  end
end
