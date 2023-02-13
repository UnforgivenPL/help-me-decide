# frozen_string_literal: true

require 'active_record'

# holds information about a user
class User < ActiveRecord::Base
end

# holds a dataset info
class DatasetInfo < ActiveRecord::Base

  def enable_and_save
    self.enabled = true
    save
  end

  def to_s = "(folder: #{folder}, user: #{user_id})"

end

module UnforgivenPL
  module HelpMeDecide

    # opens Api to allow user auth through a database
    module DbAuth

      ADMIN_USER_TIER = 9000

      def user?(token) = (@user = User.where({ token:, active: true, verified: true }).first)

      def dataset?(token) = (@dataset = DatasetInfo.where({ token:, enabled: true }).first)

      def valid_user?(token)
        @user = @dataset = nil
        token&.size == 40 && (user?(token) || dataset?(token))
      end

      def user_allowed?(_, operation, id)
        if id
          # with user token the user must be the owner of the dataset
          @dataset ||= DatasetInfo.find_by(folder: id, user_id: @user.id) if @user
          return false unless @dataset&.request_quota&.positive? || (operation == :dataset_delete)
        else
          return false unless @user
        end

        result = case operation
                 when :dataset_list then @user
                 when :dataset_new then @user && (DatasetInfo.where(user_id: @user.id, enabled: true).count < @user.dataset_quota || @user.tier > ADMIN_USER_TIER)
                 when :dataset_get, :questions, :question then @dataset && ((@user && @dataset.user_id == @user.id) || @dataset.folder == id)
                 when :dataset_delete then @dataset && @user && @dataset.user_id == @user.id
                 when :dataset_slice then @dataset && @user && @dataset.user_id == @user.id && (DatasetInfo.where(user_id: @user.id, enabled: true).count < @user.dataset_quota || @user.tier > ADMIN_USER_TIER)
                 else false
                 end
        if result && @dataset
          @dataset.request_quota -= 1
          @dataset.save
        end
        result
      end

      def dataset_created(_, _, fingerprint)
        (DatasetInfo.find_by(user_id: @user.id, enabled: false) || DatasetInfo.new(folder: fingerprint, enabled: true, user_id: @user.id, token: fingerprint)).enable_and_save if @user && fingerprint && !fingerprint.empty?
      end

      def dataset_deleted(id)
        throw(:halt, [500, 'dataset to delete is different than the one authorised']) unless @dataset.folder == id

        # no hard deleting of records, only disabling
        @dataset.enabled = false
        @dataset.save
        @dataset = nil
      end

    end
  end
end
