require 'optparse'
require_relative '../game_scraper'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: scrape_games.rb [--api_key API_KEY] [--regions=na,eune]"
  
  opts.on("--api_key API_KEY", "Provide a LOL API key") do |key|
    options[:api_key] = key
  end
  
  opts.on("--regions na,eune,euw", Array, "Scrape from only particular regions") do |list|
    options[:regions] = list
  end
end.parse!

if options[:api_key].nil?
  processor = GameScraper.new
elsif options[:regions].nil?
  processor = GameScraper.new options[:api_key]
else
  processor = GameScraper.new options[:api_key], options[:regions]
end

processor.process