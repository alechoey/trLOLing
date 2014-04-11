require 'rubygems'
require 'nokogiri'
require_relative './data_collector'
require_relative './file_factory/time_stamped_file_factory'
require_relative './file_factory/partitioned_file_factory'

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
    @data_path = File.expand_path('../../data/raw/recent_games', __FILE__)
    @index_path = File.expand_path('../../data/processed/recent_games/recent_games_index*', __FILE__)
    @output_path = File.expand_path('../../data/processed/summoner_ids', __FILE__)
    
    @data_collector = DataCollector.new
    @input_factory = FileFactory::TimeStampedFileFactory.new(@data_path, 'recent_games', 'html')
    @output_factory = FileFactory::PartitonedFileFactory.new(@output_path, 'summoner_ids', 'json')
  end

  def process
    @input_factory.each do |data_filepath|
      File.open(data_filepath, 'r') do |f|
        puts "Read recent games file #{data_filepath}..."
        document = Nokogiri::HTML(f)
        document.search('div[@class=recent-game]').each do |game_html|
          region_code = RecentGamesProcessor.get_region_code(game_html.search('small').text)
          next if region_code.nil?
          summoner_names = game_html.search('div[@class=player]').map { |player| player.at('h4') }
          
          next if summoner_names.empty?
          path = "/api/lol/#{region_code}/v1.4/summoner/by-name/#{URI.escape summoner_names.join(',')}"
          output_filepath = @output_factory.next_filepath
          @data_collector.execute path, output_filepath
          
          puts "Wrote game summoner IDs to #{output_filepath}"
        end
      end
    end
  end
  
  def self.get_region_code(region_text)
    @region_codes[region_text]
  end
end