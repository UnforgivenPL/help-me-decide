# frozen_string_literal: true

module UnforgivenPL
  module HelpMeDecide

    # skips authentication
    module NoAuth
      def valid_user?(_) = true

      def user_allowed?(*_) = true
    end
  end
end
