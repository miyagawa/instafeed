#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'digest'
require 'pathname'
require 'json'

class Instafeed
  attr_accessor :url
  
  def initialize(url)
    @url = URI.parse url
  end

  def run
    doc = Nokogiri::XML(open(url))
    doc.root.add_namespace "content", "http://purl.org/rss/1.0/modules/content/"
    doc.xpath('//item/link').each do |link|
      body = parse link.text
      node = Nokogiri::XML::Node.new "content:encoded", doc
      node.content = body
      link.add_next_sibling node
    end
    puts doc.to_xml
  end

  def parse(url)
    key = Digest::SHA1.hexdigest url
    res = cached(key) do
      sleep 1
      warn "Parsing #{url}"
      api = URI.parse 'https://www.instaparser.com/api/1/article'
      api.query = URI.encode_www_form("api_key" => ENV["INSTAPARSER_TOKEN"], "url" => url)
      open(api).read
    end

    JSON.parse(res)["html"]
  end

  def cached(key)
    file = Pathname.new(".cache/#{key}")
    file.parent.mkdir unless file.parent.directory?

    if file.exist?
      file.read
    else
      yield.tap do |result|
        file.write result
      end
    end
  end
end

Instafeed.new(*ARGV).run
