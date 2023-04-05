# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
end

require 'minitest'
require 'minitest/autorun'
require 'rack/test'
require 'json'

require 'api'
require 'auth/no_auth'

class NoAuthApi < UnforgivenPL::HelpMeDecide::Api
  include UnforgivenPL::HelpMeDecide::NoAuth
end

class ApiTest < Minitest::Test
  include Rack::Test::Methods

  TEST_DATASET = './test/data.yml'.freeze
  TEST_DATASET_ID = '3c2e6520920c39ffe932f7630445c48eaf342efc'.freeze

  def app
    NoAuthApi
  end

  def upload_test_dataset
    dataset = YAML.load_file(TEST_DATASET)
    post '/dataset', JSON.dump(dataset)
    dataset['dataset'].extend(UnforgivenPL::HelpMeDecide::Dataset)
  end

  def setup
    super
    FileUtils.rm_rf(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY)
    FileUtils.mkdir(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY)
  end

  def test_perhaps_as_bool
    { 'true' => true, 'false' => false, 'else' => 'else'}.each { |k, v| assert_equal v, k.perhaps_as_bool }
  end

  def test_version
    get '/version'
    assert_equal UnforgivenPL::HelpMeDecide::Api::APPLICATION_VERSION, last_response.body
  end

  def test_dataset
    get '/dataset'
    assert_equal [], JSON.parse(last_response.body)
    # upload a dataset
    dataset = upload_test_dataset
    assert_equal TEST_DATASET_ID, last_response.body
    # read a dataset
    get "/dataset/#{TEST_DATASET_ID}"
    assert_equal 200, last_response.status
    assert_equal dataset, JSON.parse(last_response.body)['dataset']
    # read a non-existing dataset
    get "/dataset/#{TEST_DATASET_ID.reverse}"
    assert_equal 404, last_response.status
  end

  def test_questions
    dataset = upload_test_dataset
    get "/questions/#{TEST_DATASET_ID}"
    assert_equal 200, last_response.status
    assert_equal(dataset.questions, JSON.parse(last_response.body)['questions'].transform_values { |v| v.transform_keys { |k| k =~ /\d+/ ? k.to_i : k.perhaps_as_bool } })
    get "/questions/#{TEST_DATASET_ID.reverse}"
    assert_equal 404, last_response.status
    # now with answers
    get "/questions/#{TEST_DATASET_ID}?topping=gouda"
    assert_equal 200, last_response.status
    assert_equal dataset.filter({ 'topping' => 'gouda' }), JSON.parse(last_response.body)['dataset']
    # now with impossible previous answers, so must be empty
    get "/questions/#{TEST_DATASET_ID}?topping=jam"
    assert_equal 204, last_response.status
    # now with only one answer, so no questions
    get "/questions/#{TEST_DATASET_ID}?spicy=true"
    assert_equal 200, last_response.status
    actual = JSON.parse(last_response.body)
    assert_equal dataset.slice('inferno'), actual['dataset']
    assert_empty actual['questions']
  end

  def test_question
    dataset = upload_test_dataset
    get "/question/#{TEST_DATASET_ID.reverse}"
    assert_equal 404, last_response.status
    %W[/question/#{TEST_DATASET_ID} /question/#{TEST_DATASET_ID}/first_question].each do |url|
      get url
      # with no questions asked, it should be topping (as the first defined)
      assert_equal 200, last_response.status
      actual = JSON.parse(last_response.body)
      assert_equal dataset.questions.pick(:first_question), actual['question']
    end

    # with impossible answer, should be nothing
    get "/question/#{TEST_DATASET_ID}?sides=crusty"
    assert_equal 204, last_response.status
    # narrow selection leading to only one result, thus no further questions
    get "/question/#{TEST_DATASET_ID}?topping=gouda&topping=oregano"
    assert_equal 200, last_response.status
    actual = JSON.parse(last_response.body)
    assert_equal 1, actual['dataset'].size
    assert_empty actual['question']
  end

  def test_various_failures
    post '/dataset'
    assert_equal 400, last_response.status
    [{}, { 'dataset' => {} }, { 'dataset' => 'nah' }, { 'dataset' => [] }, { 'id' => 'nah' }, { 'dataset' => { 'id' => '' } }, { 'dataset' => { 'id' => { 'feature' => %w[?invalid valid] } } }, { 'dataset' => { 'id' => { 'feat' => '-invalid' } } }, 'something something', %w[completely nonsensical] ].each do |data|
      post '/dataset', JSON.dump(data)
      assert_equal 400, last_response.status
    end
    upload_test_dataset
    get "/question/#{TEST_DATASET_ID}/non_existent_strategy"
    assert_equal 400, last_response.status
  end

  def test_semantic_error
    post '/dataset', JSON.dump( { 'dataset' => {'one' => { 'feature_one' => 'value_one', 'feature_two' => 'value_two' }, 'two' => { 'feature_one' => 'value_one', 'feature_two' => 'value_two' }, 'three' => { 'feature_one' => 'value_one', 'feature_three' => 'value_three'} } } )
    assert_equal 422, last_response.status
    assert_equal %w{one two}, JSON.parse(last_response.body)
  end

  def test_remove_dataset
    upload_test_dataset
    delete "/dataset/#{TEST_DATASET_ID}"
    assert_equal 204, last_response.status
    delete "/dataset/#{TEST_DATASET_ID}"
    assert_equal 404, last_response.status
  end

  def test_server_error_no_dataset
    FileUtils.rm_rf(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY)
    get '/dataset'
    assert_equal 500, last_response.status
    get "/dataset/#{TEST_DATASET_ID}"
    assert_equal 500, last_response.status
    get "/question/#{TEST_DATASET_ID}"
    assert_equal 500, last_response.status
    get "/questions/#{TEST_DATASET_ID}?topping=basil"
    assert_equal 500, last_response.status
    post '/dataset', JSON.dump({ 'dataset' => { 'io' => { 'feature' => 'value' } } })
    assert_equal 500, last_response.status
  end

  def test_server_error_file_problems
    FileUtils.mkdir(File.join(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY, TEST_DATASET_ID))
    upload_test_dataset
    assert_equal 500, last_response.status
    get "/dataset/#{TEST_DATASET_ID}"
    assert_equal 500, last_response.status
    FileUtils.touch(File.join(UnforgivenPL::HelpMeDecide::Api::DATASET_DIRECTORY, TEST_DATASET_ID, 'dataset.yml'))
    get "/dataset/#{TEST_DATASET_ID}"
    assert_equal 500, last_response.status
  end

  def test_read_again_from_cache
    upload_test_dataset
    get "/question/#{TEST_DATASET_ID}?topping=gouda"
    assert_equal 200, last_response.status
    actual = last_response.body
    # explicitly stating the strategy should not change anything here
    get "/question/#{TEST_DATASET_ID}/first_question?topping=gouda"
    assert_equal 200, last_response.status
    assert_equal actual, last_response.body
  end

  def test_slices
    dataset = upload_test_dataset
    get "/dataset/#{TEST_DATASET_ID}"
    assert_equal 200, last_response.status

    put "/dataset/#{TEST_DATASET_ID}", JSON.dump(['inferno'])
    assert_equal 200, last_response.status
    new_id = last_response.body

    get "/dataset/#{new_id}"
    assert_equal 200, last_response.status
    assert_equal dataset.slice('margherita', 'hawaii'), JSON.parse(last_response.body)['dataset']
  end

end
