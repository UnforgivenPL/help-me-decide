# frozen_string_literal: true

require 'active_record'

# holds information about a user
class User < ActiveRecord::Base
end

# holds a dataset info
class DatasetInfo < ActiveRecord::Base

  def to_s = "(folder: #{folder}, user: #{user_id})"

end
