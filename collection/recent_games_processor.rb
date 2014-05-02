require 'rubygems'
require 'nokogiri'
require_relative './file_factory/time_stamped_file_factory'
require_relative './file_factory/partitioned_file_factory'
require_relative './file_factory/file_factory_hierarchy'
require_relative './lol_api'

class RecentGamesProcessor
  SUMMONER_IDS_PER_FILE = 10000
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
    @raw_output_path = File.expand_path('../../data/raw/summoner_ids', __FILE__)
    
    @api = LolApi.new
    @input_factory = FileFactory::TimeStampedFileFactory.new(@data_path, 'recent_games', 'html')
    @raw_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @raw_output_path, 'summoner_ids', 'json')
  end
  
  def self.region_codes
    @region_codes
  end
  
  def region_codes
    self.class.region_codes
  end
  
  def self.get_region_code(region_text)
    @region_codes[region_text]
  end
  
  def fetch_summoners(summoner_names=[], region_code='na')
    return if summoner_names.empty?
    path = "/api/lol/#{region_code}/v1.4/summoner/by-name/#{URI.escape summoner_names.join(',')}"
    
    output_filepath = @raw_output_factory.next_filepath region_code
    @data_collector.execute path, output_filepath
    
    puts "Wrote game summoner IDs to #{output_filepath}"
  end
  
  def process
    @input_factory.each do |data_filepath|
      File.open(data_filepath, 'r') do |f|
        puts "Read recent games file #{data_filepath}"
        document = Nokogiri::HTML(f)
        document.search('div[@class=recent-game]').each do |game_html|
          region_code = RecentGamesProcessor.get_region_code(game_html.search('small').text)
          next if region_code.nil?
          summoner_names = game_html.search('div[@class=player]').map { |player| player.at('h4') }
          @api.get_summoner_ids_by_name summoner_names, region_code, @raw_output_factory.next_filepath(region_code)
        end
      end
      
      File.delete data_filepath
      puts "Removed recent games file #{data_filepath}"
    end
  end
end