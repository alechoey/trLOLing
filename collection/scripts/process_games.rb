require 'optparse'
require_relative '../game_processor'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: process_games.rb [--api_key API_KEY] [--regions=na,eune]"
  
  opts.on("--api_key API_KEY", "Provide a LOL API key") do |key|
    options[:api_keys] = [key]
  end
  
  opts.on("--api_keys API_KEY1,API_KEY2,API_KEY3", Array, "Proved multiple LOL API keys") do |list|
    options[:api_keys] = list
  end
  
  opts.on("--regions na,eune,euw", Array, "Scrape from only particular regions") do |list|
    options[:regions] = list
  end
end.parse!

if options[:api_keys].nil?
  processor = GameProcessor.new
elsif options[:regions].nil?
  processor = GameProcessor.new options[:api_keys]
else
  processor = GameProcessor.new options[:api_keys], options[:regions]
end

processor.process