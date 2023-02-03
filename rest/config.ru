# frozen_string_literal: true

require './lib/api'
require './lib/auth/db_auth'

PROD_DB_FILE = ENV['HMD_PROD_DB']

raise 'no db file specified in $HMD_PROD_DB' if PROD_DB_FILE.nil? || PROD_DB_FILE.empty?

unless File.exist?(PROD_DB_FILE)
  require './migrations/user_migrations'
  require './migrations/dataset_migrations'

  ActiveRecord::Base.establish_connection({ adapter: 'sqlite3', database: PROD_DB_FILE })

  [CreateUsers, CreateDataset].each { |t| t.new.change }
end

run UnforgivenPL::HelpMeDecide::Api.include(UnforgivenPL::HelpMeDecide::DbAuth)
