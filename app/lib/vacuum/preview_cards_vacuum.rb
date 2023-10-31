# frozen_string_literal: true

class Vacuum::PreviewCardsVacuum
  TTL = 1.day.freeze

  def initialize(retention_period)
    @retention_period = retention_period
    @storage_mode     = Paperclip::Attachment.default_options[:storage]
  end

  def perform
    vacuum_cached_images! if retention_period?
  end

  private

  def vacuum_cached_images!
    preview_cards_past_retention_period.find_each do |preview_card|
      if @storage_mode == :fog
        begin 
          retries ||= 0
          preview_card.image.destroy
        rescue Fog::Storage::OpenStack::NotFound
          # Ignore failure to delete a file that has already been deleted
        rescue
          sleep(5)
          retry if (retries += 1) < 3
        end
      else
        preview_card.image.destroy
      end
      preview_card.save
    end
  end

  def preview_cards_past_retention_period
    PreviewCard.cached.where(PreviewCard.arel_table[:updated_at].lt(@retention_period.ago))
  end

  def retention_period?
    @retention_period.present?
  end
end
