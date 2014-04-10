require 'rubygems'
require 'nokogiri'
require_relative '../data_collector'

module RecentGame
  class RecentGamesProcessor
    @region_codes = {
      'North America' => 'na',
      'Europe West' => 'euw',
      'Europe Nordic & East' => 'eune',
      'Brazil' => 'br',
      'Latin America North' => 'lan',
      'Latin America South' => 'las',
      'Oceania' => 'oce',
    }
    
    def initialize
      @data_path = File.expand_path('../../../data/raw/recent_games', __FILE__)
      @index_path = File.expand_path('../../../data/processed/recent_games/recent_games_index*', __FILE__)
      @data_collector = ::DataCollector.new
    end
  
    def process
      Dir.foreach @data_path do |data_file|
        File.open(File.join(@data_path, data_file), 'r') do |f|
          document = Nokogiri::HTML(f)
          gameno = 0
          document.search('div[@class=recent-game]').each do |game_html|
            region_code = RecentGamesProcessor.get_region_code(game_html.search('small').text)
            next if region_code.nil?
            summoner_names = game_html.search('div[@class=team-1]//div[@class=player]').map { |player| player.at('h4') }
            
            output_path = File.expand_path('../../../data/processed/summoner_ids', __FILE__)
            path = "/api/lol/#{region_code}/v1.4/summoner/by-name/#{URI.escape summoner_names.join(',')}"
            @data_collector.execute path, File.join(output_path, "summoner_ids-#{gameno}.json")
            gameno += 1
          end
        end
      end
    end
    
    def self.get_region_code(region_text)
      @region_codes[region_text]
    end
  end
end