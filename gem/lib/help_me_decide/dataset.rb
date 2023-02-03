# frozen_string_literal: true

module UnforgivenPL
  module HelpMeDecide
    # dataset is a Hash - thing -> list of features
    # there are only a few extra methods to be added
    module Dataset
      attr_accessor :definitions

      def self.extended(source)
        raise TypeError unless source.is_a?(Hash)

        dataset_values = Hash.new { |h, k| h[k] = [] }
        # dataset ids are irrelevant here
        source.each_value do |data|
          # each dataset element must be a hash
          raise TypeError unless data.is_a?(Hash)

          data.each { |feature_name, feature_value| dataset_values[feature_name] << feature_value }
        end
        # now result has all features and all possible values
        source.definitions = Hash[dataset_values.collect { |feature_name, feature_values| [feature_name, FeatureDefinition.from(feature_name, feature_values)] }].extend(FeatureDefinitions)
      end

      # filters the dataset and possibly returns a new dataset that matches given criteria
      def filter(questions = {})
        raise TypeError unless questions.is_a?(Hash)
        return self if empty? || questions.empty?

        dataset = self
        questions.each do |question, answer|
          dataset = dataset.select { |_, thing| definitions[question]&.matches?(thing, answer) }
        end

        dataset.extend(Dataset)
      end

      # prepares available questions for this dataset
      def questions
        # no questions where no data or only one element passed
        return NoQuestions.new if empty? || size == 1

        result = Hash.new { |h, k| h[k] = {} }
        definitions.each { |name, definition| result[name] = definition.organise(self) }

        # answers with all available keys should be removed
        result.each_value { |answers| answers.reject! { |_, things| things.to_set == keys.to_set } }

        # questions with no answers should be removed
        result.reject { |_, answers| answers.nil? || answers.empty? }.extend(Strategies)
      end

      # finds items that have different ids, but identical feature sets
      def find_duplicates = select { |id, features| any? { |i, f| i != id && features == f } }.keys

    end
  end
end
