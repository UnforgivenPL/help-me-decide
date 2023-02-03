# frozen_string_literal: true

module UnforgivenPL
  module HelpMeDecide
    # feature definitions are regular maps that contain FeatureDefinition as values, but they can be made pure for json
    module FeatureDefinitions
      def self.extended(source)
        raise TypeError unless source.is_a?(Hash)
        raise ArgumentError unless source.values.all? { |v| v.is_a?(FeatureDefinition) }
      end

      def pure = transform_values(&:to_map)
    end
  end
end
