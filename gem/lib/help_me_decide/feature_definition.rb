# frozen_string_literal: true

module UnforgivenPL
  module HelpMeDecide
    # defines a feature (name, type and allowed values)
    class FeatureDefinition
      ALLOWED_FEATURE_TYPES = %i[set value flag number text].freeze

      attr_accessor :name, :type, :values

      def initialize(name, type, values = [])
        super()
        raise ArgumentError unless ALLOWED_FEATURE_TYPES.include?(type) && name && values.is_a?(Array)

        @name = name
        @type = type
        @values = values
      end

      def inspect = "#{name} (#{type}) = #{values}"

      def to_s = inspect

      def to_map = { 'type' => type.to_s, 'values' => values }

      def ==(other) = other.is_a?(FeatureDefinition) && other.name == @name && other.type == @type && ((other.values.nil? && @values.nil?) || (other.values.is_a?(Array) && @values.is_a?(Array) && @values & other.values == @values))

      # checks whether a given thing matches this feature with the given value (either it includes the value, all of the values, or the value is equal to the given parameter, or the feature is a flag, value is not matching and the thing does not have it)
      def matches?(thing, value)
        (thing[name].is_a?(Array) && (thing[name].include?(value) || (value.is_a?(Array) && value.all? { |v| thing[name].include?(v) }))) ||
          (thing[name] == value) ||
          (type == :flag && thing[name].nil? && !values.include?(value)) ||
          (type == :number && thing[name].to_s == value)
      end

      # for the current feature, returns a map of value => matching dataset ids for each value
      def organise(dataset = {})
        raise ArgumentError unless dataset.is_a?(Dataset)
        return {} if dataset.empty?

        result = {}
        values.each { |value| result[value] = dataset.select { |_, thing| matches?(thing, value) }.keys }
        result
      end

      ## builds a feature definition based on the possible values given
      def self.from(name, possible_values)
        raise TypeError unless possible_values.is_a?(Array)

        # if any of the possible values is an array, then the feature is a set, with possible values from all the values passed around (unique and non-null, that is)
        return FeatureDefinition.new(name, :set, possible_values.flatten.compact.uniq) if possible_values.any? { |e| e.is_a?(Array) }

        # now no elements of the possible_values are an array
        possible_values = possible_values.compact.uniq

        # if there is only one value to choose from, the feature is a flag
        return FeatureDefinition.new(name, :flag, possible_values) if possible_values.size == 1
        # if all values are a number, then the feature is a number (values are passed anyway for easier selection)
        return FeatureDefinition.new(name, :number, possible_values) if possible_values.all? {|e| e.is_a?(Numeric)}

        # otherwise, it is a regular value feature
        FeatureDefinition.new(name, :value, possible_values)
      end

    end

  end
end
