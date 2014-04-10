require 'rubygems'
require 'nokogiri'
require 'mechanize'
require_relative '../raw_outputter'

host_name = 'http://www.lolnexus.com'
path = '/recent-games?filter-sort=2'

agent = Mechanize.new
page = agent.get(host_name + path)
recent_games_outputter = RawOutputter.new(File.expand_path('../../../data/raw/recent_games', __FILE__), 'recent_games', 'html')

next_link = nil
pageno = 1

loop do
  recent_games = page.search('div[@class=recent-games]').first.to_s
  filename = recent_games_outputter.write recent_games
  puts "Wrote recent games page number #{pageno} to #{filename}"

  pageno += 1
  next_link = page.link_with(:text => /^next$/i)

  break if next_link.nil?
  page = next_link.click
end