# frozen_string_literal: true

require 'rubygems'
require 'bundler'

Bundler.require

require './lib/api'
require './lib/auth/db_auth'

PROD_DB_FILE = ENV['HMD_PROD_DB']

raise 'no db file specified in $HMD_PROD_DB' if PROD_DB_FILE.nil? || PROD_DB_FILE.empty?
raise 'password salt not provided in $HMD_PASS_SALT' unless ENV['HMD_PASS_SALT']

require './migrations/user_migrations'
require './migrations/dataset_migrations'

ActiveRecord::Base.establish_connection({ adapter: 'sqlite3', database: PROD_DB_FILE })

unless File.exist?(PROD_DB_FILE)

  [CreateUsers, CreateDataset].each { |t| t.new.change }

  if File.exist?('./superuser.yml')
    superuser = YAML.load_file('./superuser.yml')
    %w[name password email token].each { |field| raise "missing #{field} in superuser.yml, cannot continue" if superuser[field].nil? || superuser[field].empty? }
    User.new do |user|
      user.name = superuser['name']
      user.pass = Digest::SHA1.hexdigest([superuser['name'], ENV['HMD_PASS_SALT'], superuser['password']].join('::'))
      user.email = Digest::SHA1.hexdigest([ENV['HMD_PASS_SALT'], superuser['email']].join('::'))
      user.token = Digest::SHA1.hexdigest([superuser['token'], ENV['HMD_PASS_SALT']].join('::'))
      user.verified = true
      user.active = true
      user.tier = 9001
      user.dataset_quota = 5
    end.save
    puts "superuser #{superuser['name']} created"
  end

end

run UnforgivenPL::HelpMeDecide::Api.include(UnforgivenPL::HelpMeDecide::DbAuth)
