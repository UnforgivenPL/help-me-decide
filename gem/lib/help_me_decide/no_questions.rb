# frozen_string_literal: true

module UnforgivenPL
  module HelpMeDecide
    # empty hash that returns empty question on each pick, regardless of strategy
    class NoQuestions < Hash
      def pick(_) = {}
    end
  end
end
