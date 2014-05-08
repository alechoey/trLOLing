require 'optparse'
require_relative '../recent_games_processor'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: scrape_games.rb [--api_key API_KEY]"
  
  opts.on("--api_key API_KEY", "Provide a LOL API key") do |key|
    options[:api_keys] = [key]
  end
  
  opts.on("--api_keys API_KEY1,API_KEY2,API_KEY3", Array, "Proved multiple LOL API keys") do |list|
    options[:api_keys] = list
  end
end.parse!

if options[:api_keys].nil?
  processor = RecentGamesProcessor.new
else
  processor = RecentGamesProcessor.new options[:api_keys]
end

processor.process