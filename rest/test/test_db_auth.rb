# frozen_string_literal: true

require 'active_record'

require 'auth/db_auth'

require_relative '../migrations/user_migrations'
require_relative '../migrations/dataset_migrations'

ActiveRecord::Base.establish_connection({ adapter: 'sqlite3', database: 'test/db/hmd_test.sqlite3' })

[CreateUsers, CreateDataset].each { |t| t.new.change }

TOKEN_NV     = '03b7ee92cb64b2ea2ea20015b2a9f379fdaf5bbb'
TOKEN_NA     = '0e4bdf6081bfebf2dc26c5db91fb0130eec5224b'
TOKEN_INVALID = 'e230f899bec1b5cda73cfd41840e9ccc5ce09e13'
NON_VERIFIED = User.new(name: 'not verified', pass: 'abc', email: 'nv@example.org', token: TOKEN_NV, verified: false, active: false)
NON_ACTIVE   = User.new(name: 'not active',   pass: 'abc', email: 'na@example.org', token: TOKEN_NA, verified: true,  active: false)
TOKEN_ALICE  = 'c13c73564d818ea19bbf3791ad7b2c670c7af2b4'
TOKEN_BOB    = '326c4e0379e7b571759d042a075b2e1d3e395751'
USER_ALICE   = User.new(name: 'alice', pass: 'a_password', email: 'alice@example.org', token: TOKEN_ALICE, verified: true, active: true)
USER_BOB     = User.new(name: 'bob', pass: 'another password', email: 'bob@example.org', token: TOKEN_BOB, verified: true, active: true, dataset_quota: 0)
[NON_VERIFIED, NON_ACTIVE, USER_ALICE, USER_BOB].each(&:save)

class DbAuthApi < UnforgivenPL::HelpMeDecide::Api
  include UnforgivenPL::HelpMeDecide::DbAuth
end

class DbAuthTest < Minitest::Test

  include Rack::Test::Methods

  TEST_DATASET = './test/data.yml'
  TEST_DATASET_ID = '3c2e6520920c39ffe932f7630445c48eaf342efc'

  Minitest.after_run do
    [DropDataset, DropUsers].each { |t| t.new.change }
  end

  def app
    DbAuthApi
  end

  def setup
    super
    FileUtils.rm_rf(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY)
    FileUtils.mkdir(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY)
    DatasetInfo.all.each(&:delete)
  end

  def assert_status(status = 0, tokens = [], block = nil)
    raise 'expected a block' unless block
    raise 'expected tokens' if tokens.empty?

    tokens.each do |token|
      block.call(token)
      puts last_response.body if last_response.status == 500
      assert_equal status, last_response.status
    end
  end

  def unauthorised(*tokens, &block) = assert_status(401, tokens, block)

  def forbidden(*tokens, &block) = assert_status(403, tokens, block)

  def allowed(*tokens, &block) = assert_status(200, tokens, block)

  def no_content(*tokens, &block) = assert_status(204, tokens, block)

  def no_requests(*tokens, &block) = assert_status(429, tokens, block)

  def upload_test_dataset
    dataset = JSON.dump(YAML.load_file(TEST_DATASET))
    post '/dataset', dataset, { 'Authorization' => "Bearer #{TOKEN_ALICE}" }
    assert_equal 200, last_response.status
    get '/dataset', nil, { 'Authorization' => "Bearer #{TOKEN_ALICE}" }
    assert JSON.parse(last_response.body).include?(TEST_DATASET_ID) # just to be sure
    assert DatasetInfo.find_by(folder: TEST_DATASET_ID) # must be in the db
    TEST_DATASET_ID
  end

  def test_no_data_at_start
    assert_equal 4, User.all.size
    assert_empty DatasetInfo.all
  end

  def test_new_dataset_valid_user
    dataset = JSON.dump(YAML.load_file(TEST_DATASET))

    operation = ->(token) { post '/dataset', dataset, { 'Authorization' => "Bearer #{token}" } }

    # no token or token of an invalid, not active and not verified user - 401
    post '/dataset', dataset
    assert_equal 401, last_response.status

    unauthorised(TOKEN_NA, TOKEN_NV, TOKEN_INVALID, &operation)

    # bob cannot add a dataset, his quota is 0
    forbidden(TOKEN_BOB, &operation)

    # alice can safely add a dataset
    allowed(TOKEN_ALICE, &operation)
  end

  def test_list_datasets
    # listing datasets should be allowed for any valid user
    operation = ->(token) { get '/dataset', nil, { 'Authorization' => "Bearer #{token}" } }
    unauthorised(TOKEN_NA, TOKEN_NV, TOKEN_INVALID, &operation)
    allowed(TOKEN_ALICE, TOKEN_BOB, &operation)
  end

  def test_dataset_operations
    upload_test_dataset
    # dataset must be enabled
    # getting an individual dataset is possible in two cases:
    # - token of the dataset matches
    # - token of the owner of the dataset matches
    alice = User.find_by(token: TOKEN_ALICE)

    requests_left = alice.request_quota
    assert requests_left > 0
    requests_made = DatasetInfo.find_by(folder: TEST_DATASET_ID)&.requests
    %w[dataset questions question].map { |s| "/#{s}/#{TEST_DATASET_ID}" }
                                  .map { |s| ->(token) { get(s, nil, { 'Authorization' => "Bearer #{token}" }) } }
                                  .each do |operation|
      unauthorised(TOKEN_INVALID, TOKEN_NV, TOKEN_NA, &operation)
      forbidden(TOKEN_BOB, &operation)
      allowed(TOKEN_ALICE, &operation)
      allowed(TEST_DATASET_ID, &operation)
      requests_left -= 2
      requests_made += 2
      # now after two successful gets the number of requests available should decrease accordingly
      assert_equal requests_left, User.find_by(token: TOKEN_ALICE)&.request_quota
      assert_equal requests_made, DatasetInfo.find_by(folder: TEST_DATASET_ID)&.requests
    end
  end

  def test_no_requests_left
    upload_test_dataset
    alice = User.find_by(token: TOKEN_ALICE)
    alice.request_quota = 0
    alice.save!

    %w[dataset questions question].map { |s| "/#{s}/#{TEST_DATASET_ID}" }
                                  .map { |s| ->(token) { get(s, nil, { 'Authorization' => "Bearer #{token}" }) } }
                                  .each do |operation|
      assert_equal 0, User.find_by(id: alice.id)&.request_quota
      no_requests(TOKEN_ALICE, &operation)
      no_requests(TEST_DATASET_ID, &operation)
    end

    alice.request_quota = 1000
    alice.save!
  end

  def test_slice_dataset
    upload_test_dataset
    requests_left = User.find_by(token: TOKEN_ALICE)&.request_quota
    operation = ->(token) { put "/dataset/#{TEST_DATASET_ID}", JSON.dump(['margherita']), { 'Authorization' => "Bearer #{token}" } }
    unauthorised(TOKEN_INVALID, TOKEN_NV, TOKEN_NA, &operation)
    forbidden(TOKEN_BOB, &operation)
    allowed(TOKEN_ALICE, &operation)
    sliced_id = last_response.body
    assert sliced_id.size == 40
    # slicing should reduce number of available requests
    assert_equal requests_left-1, User.find_by(token: TOKEN_ALICE)&.request_quota
    # but not increase the number of calls
    assert_equal 0, DatasetInfo.find_by(folder:TEST_DATASET_ID)&.requests

    # now it should be ok to fetch the sliced dataset
    operation = ->(token) { get "/dataset/#{sliced_id}", nil, { 'Authorization' => "Bearer #{token}" } }
    unauthorised(TOKEN_INVALID, TOKEN_NV, TOKEN_NA, &operation)
    forbidden(TOKEN_BOB, &operation)
    allowed(TOKEN_ALICE, &operation)
  end

  def test_delete_dataset
    upload_test_dataset

    operation = ->(token) { delete "/dataset/#{TEST_DATASET_ID}", nil, { 'Authorization' => "Bearer #{token}" } }
    unauthorised(TOKEN_INVALID, TOKEN_NV, TOKEN_NA, &operation)
    forbidden(TOKEN_BOB, &operation)
    no_content(TOKEN_ALICE, &operation)
    assert_nil DatasetInfo.find_by(folder: TEST_DATASET_ID, enabled: true)
    dataset = DatasetInfo.find_by(folder: TEST_DATASET_ID, enabled: false)

    # set the number of requests to some number
    dataset.requests = 200
    dataset.save

    upload_test_dataset
    # after uploading a previously deleted dataset the record should be reused
    other = DatasetInfo.find_by(folder: TEST_DATASET_ID, enabled: true)
    assert_equal dataset.id, other.id
    assert_equal dataset.requests, other.requests
    # deleting should not be possible with dataset token, only with user token
    forbidden(TEST_DATASET_ID, &operation)
    assert DatasetInfo.find_by(folder: TEST_DATASET_ID)
  end

end
