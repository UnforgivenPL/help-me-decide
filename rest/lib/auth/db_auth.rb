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

  def owner
    @owner ||= User.find(user_id)
  end

  def to_s = "(folder: #{folder}, owner: #{user_id})"

end

module UnforgivenPL
  module HelpMeDecide

    QUOTA_OPERATIONS = [:dataset_get, :questions, :question, :dataset_slice].freeze

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
        # operation is free, or the user has enough request quota (if user token used), or the owner of the dataset has
        free_action = !QUOTA_OPERATIONS.include?(operation) || (@user && @user.request_quota&.positive?) || (@dataset&.owner&.request_quota&.positive?)

        if id
          # with user token the user must be the owner of the dataset
          @dataset ||= DatasetInfo.find_by(folder: id, user_id: @user.id) if @user
          return false unless @dataset && free_action
        else
          return false unless @user && free_action
        end

        result = case operation
                 when :dataset_list then @user
                 when :dataset_new then @user && (DatasetInfo.where(user_id: @user.id, enabled: true).count < @user.dataset_quota || @user.tier > ADMIN_USER_TIER)
                 when :dataset_get, :questions, :question then @dataset && ((@user && @dataset.user_id == @user.id) || @dataset.folder == id)
                 when :dataset_delete then @dataset && @user && @dataset.user_id == @user.id
                 when :dataset_slice then @dataset && @user && @dataset.user_id == @user.id && (DatasetInfo.where(user_id: @user.id, enabled: true).count < @user.dataset_quota || @user.tier > ADMIN_USER_TIER)
                 else false
                 end
        # decrease the number of available requests (and increase counter for stats) if needed
        if result && @dataset && QUOTA_OPERATIONS.include?(operation)
          owner = @user || @dataset.owner
          # make sure the requests are reduced even if dataset token is used
          owner.request_quota -= 1
          owner.save
          unless operation == :dataset_slice
            @dataset.requests += 1
            @dataset.save
          end

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
