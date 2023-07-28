# frozen_string_literal: true

require 'active_record'

class LogEntry < ActiveRecord::Base
end

module UnforgivenPL
  module HelpMeDecide

    module DbLog

      def log(session_id:, operation:, dataset: nil, answers: nil, strategy: nil, question: nil)
        LogEntry.new(session: session_id, operation: operation, dataset_id: dataset, strategy: strategy, question: question, answers: answers).save!
      end

    end

  end
end