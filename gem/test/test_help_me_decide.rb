# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
end

require 'minitest/autorun'
require 'yaml'
require 'help_me_decide'

class EngineTest < Minitest::Test

  include UnforgivenPL::HelpMeDecide

  TEST_DATA = YAML.load_file('./test/data.yml')

  PIZZAS = TEST_DATA['dataset'].extend(Dataset)

  DEFINED_FEATURES = PIZZAS.definitions

  def test_definition_exceptions
    assert_raises ArgumentError do
      FeatureDefinition.new('something', 'unknown')
    end
    assert_raises ArgumentError do
      FeatureDefinition.new(nil , :value)
    end
    assert_raises TypeError do
      FeatureDefinition.from('something', 'something')
    end
    assert_raises ArgumentError do
      FeatureDefinition.from(nil , [])
    end
  end

  def test_extract_features
    expected = {'topping' => FeatureDefinition.new('topping', :set, %w[mozzarella basil tomatoes gouda oregano ham chili jalapeno tabasco pineapple]),
                'sizes' => FeatureDefinition.new('sizes', :set, %w[xl normal]),
                'ingredients' => FeatureDefinition.new('ingredients', :number, [3, 4, 7]),
                'spicy' => FeatureDefinition.new('spicy', :flag),
                'evening_drink' => FeatureDefinition.new('evening_drink', :value, ['white wine', 'water'])
    }
    assert_equal expected.size, DEFINED_FEATURES.size
    expected.each { |name, definition| assert_equal definition, DEFINED_FEATURES[name] }
  end

  def test_organise_non_dataset
    assert_raises ArgumentError do
      DEFINED_FEATURES['topping'].organise(Hash.new)
    end
  end

  def test_dataset_is_hash
    assert_raises TypeError do
      %w[makes no sense].extend(Dataset)
    end
    assert_raises TypeError do
      {'value' => 'must be an array'}.extend(Dataset)
    end
  end

  def test_strategies_are_hash
    assert_raises TypeError do
      'makes no sense'.extend(Strategies)
    end
  end

  def test_filter_dataset
    assert_equal PIZZAS.slice('margherita', 'hawaii'), PIZZAS.filter({ 'topping' => 'basil' })
    assert_equal PIZZAS.slice('inferno'), PIZZAS.filter({ 'topping' => 'gouda', 'spicy' => true })
    assert_equal PIZZAS.slice('hawaii'), PIZZAS.filter({ 'topping' => %w[basil pineapple] })
    assert_equal PIZZAS.slice('margherita', 'hawaii'), PIZZAS.filter({ 'spicy' => false })
    assert_empty PIZZAS.filter({ 'topping' => 'peach' })
    assert_same PIZZAS, PIZZAS.filter

    assert_raises TypeError do
      PIZZAS.filter(%w[makes no sense])
    end
  end

  def test_features_match
    assert_equal true, DEFINED_FEATURES['topping'].matches?(PIZZAS['hawaii'], %w[basil gouda]) # this has a different order than in the definition, but still must match
  end

  def test_organise_empty_dataset
    assert_equal({}, DEFINED_FEATURES['spicy'].organise(Hash.new.extend(Dataset)))
  end

  def test_questions_available
    # original questions for the entire dataset
    expected = {
      'topping' => {
        'mozzarella' => %w[margherita],
        'basil' => %w[margherita hawaii],
        'tomatoes' => %w[margherita inferno],
        'gouda' => %w[inferno hawaii],
        'oregano' => %w[inferno],
        'ham' => %w[inferno hawaii],
        'chili' => %w[inferno],
        'jalapeno' => %w[inferno],
        'tabasco' => %w[inferno],
        'pineapple' => %w[hawaii]
      },
      'sizes' => {
        'xl' => %w[margherita inferno],
        # since normal size is applicable to everything, it should not be included in the results
        # 'normal' => %w{margherita inferno hawaii}
      },
      'ingredients' => {
        3 => %w[margherita],
        7 => %w[inferno],
        4 => %w[hawaii]
      },
      'spicy' => {
        true => %w[inferno]
      },
      'evening_drink' => {
        'white wine' => %w[margherita hawaii],
        'water' => %w[inferno]
      }
    }
    assert_equal expected, PIZZAS.questions
    assert_equal expected, PIZZAS.filter({}).questions

    # questions after one selection
    expected = {
      'topping' => {
        'mozzarella' => %w[margherita],
        # basil should not be included, as it contains both ids AND it has been asked
        # 'basil' => %w{margherita hawaii},
        'tomatoes' => %w[margherita],
        'gouda' => %w[hawaii],
        'ham' => %w[hawaii],
        'pineapple' => %w[hawaii]
      },
      'sizes' => {
        'xl' => %w[margherita]
        # normal should not be included, as it contains both ids
        # 'normal' => %w{margherita hawaii}
      },
      'ingredients' => {
        3 => %w[margherita],
        4 => %w[hawaii]
      }
      # the evening drink has only one value AND all possible ids are included
      # it should thus not be available as a question (no sense in asking it)
      # 'evening_drink' => {
      #    'white wine' => %w{margherita hawaii}
      # }
    }
    assert_equal expected, PIZZAS.filter({'topping' => 'basil'}).questions

  end

  def test_no_questions_available
    # only one thing matches
    assert_equal({}, PIZZAS.filter({'spicy' => true}).questions)
    # only one thing matches, but with two questions
    assert_equal({}, PIZZAS.filter({'topping' => 'basil', 'size' => 'normal'}).questions)
    # nothing matches
    assert_equal({}, PIZZAS.filter({'topping' => 'peach'}).questions)
  end

  def test_pick_unavailable_strategy
    assert_raises ArgumentError do
      PIZZAS.questions.pick(:no_strategy_like_this)
    end
    assert_raises ArgumentError do
      {}.extend(Strategies).first_question('completely unrealistic')
    end
  end

  def test_pick_first_strategy
    expected = { 'topping' => {
      'mozzarella' => %w[margherita],
      'basil' => %w[margherita hawaii],
      'tomatoes' => %w[margherita inferno],
      'gouda' => %w[inferno hawaii],
      'oregano' => %w[inferno],
      'ham' => %w[inferno hawaii],
      'chili' => %w[inferno],
      'jalapeno' => %w[inferno],
      'tabasco' => %w[inferno],
      'pineapple' => %w[hawaii]
    } }
    assert_equal expected, PIZZAS.questions.pick(:first_question)
  end

  def test_definitions_yaml_map
    assert_equal false, DEFINED_FEATURES.pure.to_yaml.include?('!')
  end

  def test_find_duplicates
    assert_empty PIZZAS.find_duplicates
    assert_equal %w{id other}, { 'id' => { 'foo' => 'bar' }, 'other' => { 'foo' => 'bar' } }.extend(Dataset).find_duplicates
    assert_equal %w{id other}, { 'id' => { 'foo' => 'bar' }, 'good' => { 'bar' => 'foo'}, 'other' => { 'foo' => 'bar' } }.extend(Dataset).find_duplicates
  end

  def test_feature_defs_extensions
    assert_raises TypeError do
      'no sense'.extend(FeatureDefinitions)
    end
    assert_raises ArgumentError do
      { no: 'sense', at: 'all' }.extend(FeatureDefinitions)
    end
  end

end
