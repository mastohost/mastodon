# frozen_string_literal: true

require 'singleton'

class RemoteSynchronizationManager
  include Singleton
  include RoutingHelper

  PROCESSING_VALUE = '!processing'.freeze
  LOCK_TIME        = 5.minutes.seconds
  CACHE_TIME       = 1.day.seconds

  def get_processed_url(remote_url)
    redis = synchronization_redis
    Rails.logger.debug "synchronization_redis: #{redis}"
    return if redis.nil?

    lock_options = { redis: redis, key: "process:#{remote_url}" }

    Rails.logger.debug "lock_options: #{lock_options}"

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        url = redis.get("processed_media_url:#{remote_url}")
        redis.setex("processed_media_url:#{remote_url}", LOCK_TIME, PROCESSING_VALUE) if url.nil?
        url
      else
        nil
      end
    end
  rescue Redis::BaseError => e
    Rails.logger.warn "Error during synchronization: #{e}"
    nil
  end

  def set_processed_url(remote_url, object_url)
    redis = synchronization_redis
    return if redis.nil?

    Rails.logger.debug "object_url: #{object_url}"

    if object_url.nil?
      redis.del("processed_media_url:#{remote_url}")
    else
      redis.setex("processed_media_url:#{remote_url}", CACHE_TIME, full_asset_url(object_url))
    end
  rescue Redis::BaseError => e
    Rails.logger.warn "Error during synchronization: #{e}"
    nil
  end

  private

  def synchronization_redis
    return @synchronization_redis if defined?(@synchronization_redis)

    redis_url = Rails.configuration.x.synchronization_redis_url
    return unless redis_url.present?

    redis_connection = Redis.new(
      url: redis_url,
      driver: :hiredis
    )

    namespace = Rails.configuration.x.synchronization_redis_namespace

    if namespace
      @synchronization_redis = Redis::Namespace.new(namespace, redis: redis_connection)
    else
      @synchronization_redis = redis_connection
    end

    @synchronization_redis
  end
end
