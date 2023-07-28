# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'yaml'
require 'digest'
require 'fileutils'
require 'cgi'
require 'help_me_decide'
require 'securerandom'

# open String to add helper method to convert itself to a boolean, if applicable
class String
  def perhaps_as_bool
    case self
    when 'true' then true
    when 'false' then false
    else self
    end
  end

  def maybe_raw = self =~ /\d+/ ? to_i : perhaps_as_bool

  def begin_with_alphanum? = self[0].match?(/\p{Alnum}/)
end

# open Array to unwrap the first element (ensuring it is a bool, if possible)
class Array
  def unwrap = size == 1 ? first.perhaps_as_bool : self
end

class Hash
  def add_if(key, value)
    self[key] = value if key && value
    self
  end
end

module UnforgivenPL
  module HelpMeDecide

    # reference implementation of the api
    class Api < Sinatra::Application

      DATASET_DIRECTORY = ENV['HMD_DATASET_DIRECTORY'] || 'datasets'
      DATASET_FILE = 'dataset.yml'
      DEFINITIONS_FILE = 'definitions.yml'
      APPLICATION_VERSION = 'HelpMeDecide 0.1.0'
      SESSION_ID_LENGTH = 64

      def ensure_session!
        # session id (either passed or make new)
        param_session = request.params['_session']
        throw(:halt, [400, 'bad session id']) if param_session && param_session !~ /^[a-f0-9]{64}$/

        @session = param_session || SecureRandom.hex(SESSION_ID_LENGTH/2)
      end

      def authorise!(operation, dataset_id = nil)
        @dataset_id = dataset_id
        @operation = operation

        throw(:halt, [500, 'no authorisation method provided; implement :valid_user? and :user_allowed?']) unless respond_to?(:valid_user?) && respond_to?(:user_allowed?)
        actual_header = request.env['HTTP_AUTHORIZATION'] || request.env['Authorization'] || ''
        access_token = actual_header&.[](7..-1)
        throw(:halt, [401, 'unauthenticated']) unless valid_user?(access_token)
        throw(:halt, [403, 'invalid user']) unless user_allowed?(access_token, operation, dataset_id)
        # quota checking is optional (and by default no quota checks are done)
        throw(:halt, [429, 'no requests left']) if respond_to?(:quota_ok?) && !quota_ok?(access_token, operation)

        ensure_session!
      end

      def save_dataset(incoming)
        return [400, 'invalid format, expected a map with a dataset'] unless incoming.is_a?(Hash)
        return [400, 'missing dataset'] unless incoming['dataset']
        return [400, 'dataset must be a non-empty map'] unless incoming['dataset'].is_a?(Hash) && !incoming['dataset'].empty?
        return [400, 'all items in the dataset must have an id and features'] if incoming['dataset'].any? { |id, value| value.nil? || !value.is_a?(Hash) || value.empty? || id.empty? }
        return [400, 'all feature value in the dataset must begin with a letter or a digit'] if incoming['dataset'].any? { |_, things| things.values.any? { |v| (v.is_a?(String) && !v.begin_with_alphanum?) || (v.is_a?(Array) && v.any? { |k| k.is_a?(String) && !k.begin_with_alphanum? } ) } }

        dataset = incoming['dataset'].extend(UnforgivenPL::HelpMeDecide::Dataset)
        duplicates = dataset.find_duplicates
        return [422, JSON.dump(duplicates)] unless duplicates.empty?

        incorrect = dataset.find_missing
        return [422, JSON.dump(incorrect)] unless incorrect.empty?

        definition = dataset.definitions

        dataset_yaml = dataset.to_yaml

        @dataset_id = respond_to?(:dataset_fingerprint) ? dataset_fingerprint(dataset) : Digest::SHA1.hexdigest(dataset_yaml)

        return [500, 'directory already exists; problem reported'] if Dir.exist?(File.join(DATASET_DIRECTORY, @dataset_id))

        return [500, 'filesystem error; problem reported'] unless Dir.mkdir(File.join(DATASET_DIRECTORY, @dataset_id))
        return [500, 'cannot write dataset file; problem reported'] unless File.write(File.join(DATASET_DIRECTORY, @dataset_id, DATASET_FILE), dataset_yaml)
        return [500, 'cannot write definitions file; problem reported'] unless File.write(File.join(DATASET_DIRECTORY, @dataset_id, DEFINITIONS_FILE), definition.pure.to_yaml)

        dataset_created(dataset, definition, @dataset_id) if respond_to?(:dataset_created)

        [200, @dataset_id]
      end

      before do
        throw(:halt, [500, 'server filesystem error - no dataset directory']) unless Dir.exist?(DATASET_DIRECTORY)
      end

      after do
        # log only successful responses
        log(session_id: @session, operation: @operation, dataset: @dataset_id, answers: @answers, strategy: @strategy, question: @question) if respond_to?(:log) && response.status/100 == 2
      end

      get '/' do
        APPLICATION_VERSION
      end

      get '/version' do
        APPLICATION_VERSION
      end

      # returns all available datasets
      get '/dataset' do
        authorise!(:dataset_list)
        json(Dir.entries(DATASET_DIRECTORY).filter { |entry| !entry.start_with?('.') && File.directory?(File.join(DATASET_DIRECTORY, entry)) })
      end

      # creates a new dataset
      post '/dataset' do
        authorise!(:dataset_new)
        request.body.rewind
        incoming = JSON.parse request.body.read rescue throw(:halt, [400, 'invalid data format'])
        save_dataset(incoming)
      end

      def dataset_directory(id)
        directory = File.join(DATASET_DIRECTORY, id)
        throw(:halt, [404, 'dataset not found']) unless Dir.exist?(directory)
        directory
      end

      def read_dataset(id, answers = {})
        directory = dataset_directory(id)
        answers_hash, answered_file = if answers.empty?
                                        [nil, nil]
                                      else
                                        h = Digest::SHA1.hexdigest(answers.to_yaml)
                                        [h, "#{File.join(directory, h)}.yml"]
                                      end

        # first check if the reduced file is there
        dataset = if answers_hash && answered_file && File.exist?(answered_file)
                    YAML.load_file(answered_file).extend(UnforgivenPL::HelpMeDecide::Dataset)
                  else
                    paths = [DATASET_FILE, DEFINITIONS_FILE].collect { |p| File.join(directory, p) }
                    throw(:halt, [500, 'dataset file not located; problem reported']) unless File.exist?(paths[0])
                    throw(:halt, [500, 'definition file not located; problem reported']) unless File.exist?(paths[1])
                    d = YAML.load_file(paths[0]).extend(UnforgivenPL::HelpMeDecide::Dataset)
                    # store for future use
                    if answered_file
                      d = d.filter(answers)
                      File.write(answered_file, d.to_yaml) unless d.empty? # not saving if nothing to save
                    end
                    d
                  end

        throw(:halt, 204) if dataset.empty?

        [dataset, dataset.definitions]
      end

      put %r{/dataset/([a-fA-F0-9]{40})} do |id|
        authorise!(:dataset_slice, id)
        dataset, = read_dataset(id)
        request.body.rewind
        raw_data = request.body.read
        throw(:halt, [400, 'request body must not be empty']) if raw_data.empty?

        filters = JSON.parse(raw_data) rescue throw(:halt, [400, 'incorrect request body'])

        throw(:halt, [400, 'request body must be an array']) unless filters.is_a?(Array)

        sliced = dataset.except(*filters)
        throw(:halt, 204) if sliced.empty?

        save_dataset({ 'dataset' => sliced })
      end

      get %r{/dataset/([a-fA-F0-9]{40})} do |id|
        authorise!(:dataset_get, id)
        dataset, definitions = read_dataset(id)
        json({ 'definition' => definitions, 'dataset' => dataset, 'strategies' => UnforgivenPL::HelpMeDecide::Strategies::AVAILABLE_STRATEGIES }.add_if('_session', @session))
      end

      delete %r{/dataset/([a-fA-F0-9]{40})} do |id|
        authorise!(:dataset_delete, id)
        FileUtils.rm_rf(dataset_directory(id))
        dataset_deleted(id) if respond_to?(:dataset_deleted)
        204
      end

      def read_answers(request)
        # params that start with _ are internal and thus removed
        CGI.parse(request.query_string).transform_values(&:unwrap).delete_if { |k| k.start_with?('_') }
      end

      get %r{/questions/([a-fA-F0-9]{40})} do |id|
        authorise!(:questions, id)
        @answers = read_answers(request).transform_values { |value| value.to_s.maybe_raw }
        dataset, definitions = read_dataset(id, @answers)

        json({'definition' => definitions.pure, 'dataset' => dataset, 'strategies' => UnforgivenPL::HelpMeDecide::Strategies::AVAILABLE_STRATEGIES, 'questions' => dataset.questions, 'answers' => @answers}.add_if('_session', @session))
      end

      get %r{/question/([a-fA-F0-9]{40})(/([a-z_]{1,32}))?} do |id, _, strategy|
        authorise!(:question, id)
        strategy = UnforgivenPL::HelpMeDecide::Strategies::AVAILABLE_STRATEGIES.first if strategy.nil?
        strategy = strategy.to_sym unless strategy.is_a?(Symbol)
        throw(:halt, [400, 'incorrect strategy']) unless UnforgivenPL::HelpMeDecide::Strategies::AVAILABLE_STRATEGIES.include?(strategy)

        @answers = read_answers(request)
        dataset, definitions = read_dataset(id, @answers)

        @question = dataset.questions.pick(@strategy = strategy)

        json({'definition' => definitions.pure, 'dataset' => dataset, 'strategies' => UnforgivenPL::HelpMeDecide::Strategies::AVAILABLE_STRATEGIES, 'question' => @question, 'answers' => @answers}.add_if('_session', @session))
      end

    end # class Api
  end # module
end # unforgiven.pl
