#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'digest'
require 'pathname'
require 'json'
require 'readability'

class Instafeed
  attr_accessor :url
  
  def initialize(url)
    @url = URI.parse url
  end

  def run
    doc = Nokogiri::XML(open(url))
    doc.root.add_namespace "content", "http://purl.org/rss/1.0/modules/content/"
    doc.root.add_namespace "dc", "http://purl.org/dc/elements/1.1/"
    doc.xpath('//item/link').each do |link|
      article = parse link.text

      if article["content"]
        node = Nokogiri::XML::Node.new "content:encoded", doc
        node.content = article["content"]
        link.add_next_sibling node
      end
    end

    puts doc.to_xml
  end

  def parse(url)
    key = Digest::SHA1.hexdigest url
    res = cached(key) do
      warn "Parsing #{url}"

      api = URI.parse 'https://mercury.postlight.com/parser'
      api.query = URI.encode_www_form("url" => url)
      article = JSON.parse(open(api, "x-api-key" => ENV['MERCURY_API_KEY']).read)

      unless article["content"]
        source = open(url, allow_redirections: :safe).read
        article["content"] = Readability::Document.new(
          source,
          tags: %w[div p a img i strong em ul li pre blockquote code h1 h2 h3 h4],
          attributes: %w[href src],
          remove_empty_nodes: true,
        ).content
      end

      JSON.dump(article)
    end

    JSON.parse(res)
  rescue Exception => e
    warn e
    {}
  end

  def cached(key)
    file = Pathname.new(".cache/#{key}")
    file.parent.mkdir unless file.parent.directory?

    if file.exist?
      file.read
    else
      yield.tap do |result|
        File.open(file, 'w') { |file| file.write result }
      end
    end
  end
end

Instafeed.new(*ARGV).run
