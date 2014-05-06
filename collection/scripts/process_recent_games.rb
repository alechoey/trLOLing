require 'optparse'
require_relative '../recent_games_processor'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: scrape_games.rb [--api_key API_KEY]"
  
  opts.on("--api_key API_KEY", "Provide a LOL API key") do |key|
    options[:api_key] = key
  end
end.parse!

if options[:api_key].nil?
  processor = RecentGamesProcessor.new
else
  processor = RecentGamesProcessor.new options[:api_key]
end

processor.process