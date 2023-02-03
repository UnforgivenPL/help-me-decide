# frozen_string_literal: true

module UnforgivenPL
  module HelpMeDecide
    # holds strategies
    module Strategies

      AVAILABLE_STRATEGIES = %i[first_question random_question].freeze

      def self.extended(into)
        raise TypeError unless into.is_a?(Hash)
      end

      def first_question(questions = {})
        raise ArgumentError unless questions.is_a?(Hash)

        questions.slice(questions.keys.first)
      end

      def random_question(questions = {})
        raise ArgumentError unless questions.is_a?(Hash)

        questions.slice(questions.keys.sample)
      end

      def pick(strategy = :first_question)
        raise ArgumentError unless Strategies.instance_methods.include?(strategy)

        send(strategy, self)
      end
    end
  end
end
