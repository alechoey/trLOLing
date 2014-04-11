require 'rubygems'
require 'bloomfilter-rb'
require 'nokogiri'
require_relative './data_collector'
require_relative './file_factory/time_stamped_file_factory'
require_relative './file_factory/partitioned_file_factory'
require_relative './util/csv_utilities'

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
    @processed_output_path = File.expand_path('../../data/processed/summoner_ids', __FILE__)
    @bf_path = File.expand_path('../../data/processed/summoner_ids/summoners_seen', __FILE__)
    
    @data_collector = DataCollector.new
    @input_factory = FileFactory::TimeStampedFileFactory.new(@data_path, 'recent_games', 'html')
    @raw_output_factory = FileFactory::PartitionedFileFactory.new(@raw_output_path, 'summoner_ids', 'json')
    @processed_output_factory = FileFactory::PartitionedFileFactory.new(@processed_output_path, 'summoner_ids', 'csv')
    
    @processed_output_headers = ['id', 'name', 'profileIconId', 'summonerLevel', 'revisionDate']
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
          output_filepath = @raw_output_factory.next_filepath
          @data_collector.execute path, output_filepath
          
          puts "Wrote game summoner IDs to #{output_filepath}"
        end
      end
      
      File.delete data_filepath
      puts "Removed recent games file #{data_filepath}"
    end
    
    if File.exists? @bf_path
      puts "Loading summoners seen bloom filter from file #{@bf_path}"
      summoners_seen = BloomFilter::Native.load @bf_path
    else
      summoners_seen = BloomFilter::Native.new(
          :size => 12000000,
          :hashes => 12,
          :seed => 1,
          :bucket => 3,
          :raise => false)
      puts 'Initializing new summoners seen bloom filter'
    end

    num_headers = @processed_output_headers.count
    processed_values = []
    @raw_output_factory.each do |raw_summoner_filepath|
      File.open(raw_summoner_filepath, 'r') do |f|
        raw_summoners = JSON.parse f.read
        raw_summoners.each do |summoner_name, summoner_values|
          values = @processed_output_headers.map { |key| summoner_values[key] }
          next if values.count { |val| !val.nil? } < num_headers
          next if summoners_seen.include? summoner_name
          
          processed_values << values
          summoners_seen.insert summoner_name
        end
      end
      
      File.delete raw_summoner_filepath
      puts "Removed raw summoner ID file #{raw_summoner_filepath}"
      
      if processed_values.count > SUMMONER_IDS_PER_FILE
        values_to_write = processed_values.slice! 0, SUMMONER_IDS_PER_FILE
        processed_filepath = @processed_output_factory.next_filepath
        CSV.write processed_filepath, values_to_write, @processed_output_headers
        puts "Wrote #{SUMMONER_IDS_PER_FILE} summoner IDs to file #{processed_filepath}"
      end
    end
    
    unless processed_values.empty?
      processed_filepath = @processed_output_factory.next_filepath
      CSV.write processed_filepath, processed_values, @processed_output_headers
      puts "Wrote remaining summoner IDS to file #{processed_filepath}"
    end
        
    summoners_seen.save @bf_path
    puts "Saved summoners seen filter to #{@bf_path}"
  end
  
  def self.get_region_code(region_text)
    @region_codes[region_text]
  end
end