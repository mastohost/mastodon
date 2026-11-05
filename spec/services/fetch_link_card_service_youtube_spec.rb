# frozen_string_literal: true

require 'rails_helper'

# mastohost: a link to one YouTube video asks YouTube's oEmbed endpoint directly.
RSpec.describe FetchLinkCardService do
  subject { described_class.new }

  let(:status) { Fabricate(:status, text: url) }
  let(:oembed) { 'https://www.youtube.com/oembed' }

  before do
    stub_request(:get, /youtu/).to_return(headers: { 'Content-Type' => 'text/html' }, body: '<!doctype html><title>YouTube</title>')
    stub_request(:get, oembed).with(query: hash_including({})).to_return(headers: { 'Content-Type' => 'application/json' }, body: '{ "version": "1.0", "type": "link", "title": "A video" }')

    subject.call(status)
  end

  {
    'a watch link' => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'v after another parameter' => 'https://www.youtube.com/watch?feature=share&v=dQw4w9WgXcQ',
    'a short link' => 'https://youtu.be/dQw4w9WgXcQ?si=abc',
    'a short on mobile' => 'https://m.youtube.com/shorts/dQw4w9WgXcQ',
    'a live link' => 'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share',
    'an embed' => 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?start=10',
    'an attribution link' => 'https://www.youtube.com/attribution_link?a=x&u=%2Fwatch%3Fv%3DdQw4w9WgXcQ%26feature%3Dshare',
  }.each do |what, link|
    context "with #{what} to YouTube" do
      let(:url) { link }

      it 'asks oEmbed for that video' do
        expect(a_request(:get, oembed).with(query: { url: 'https://youtube.com/watch?v=dQw4w9WgXcQ', format: 'json' })).to have_been_made.once
        expect(status.preview_card&.title).to eq 'A video'
      end
    end
  end

  {
    'a parameter ending in v' => 'https://www.youtube.com/watch?dev=abcdefghijk',
    'a playlist embed' => 'https://www.youtube.com/embed/videoseries?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG',
    'a redirect off YouTube' => 'https://www.youtube.com/redirect?q=https%3A%2F%2Fevil.example%2F%3Fv%3DdQw4w9WgXcQ',
    'an ID too short' => 'https://www.youtube.com/watch?v=dQw4w9',
    'a bad byte in v' => 'https://www.youtube.com/watch?v=%FFQw4w9WgXc',
  }.each do |what, link|
    context "with #{what} to YouTube" do
      let(:url) { link }

      it 'does not ask oEmbed' do
        expect(a_request(:get, /oembed/)).to_not have_been_made
      end
    end
  end
end
