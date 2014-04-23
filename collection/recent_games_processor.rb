require 'rubygems'
require 'bloom-filter'
require 'nokogiri'
require_relative './data_collector'
require_relative './file_factory/time_stamped_file_factory'
require_relative './file_factory/partitioned_file_factory'
require_relative './file_factory/dummy_file_factory'
require_relative './file_factory/file_factory_hierarchy'
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
    
    @data_collector = DataCollector.new
    @input_factory = FileFactory::TimeStampedFileFactory.new(@data_path, 'recent_games', 'html')
    @raw_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @raw_output_path, 'summoner_ids', 'json')
    @processed_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @processed_output_path, 'summoner_ids', 'csv')
    @bloom_filter_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::DummyFileFactory, @processed_output_path, 'summoners_seen', 'bloom')
    
    @processed_output_headers = ['id', 'name', 'profileIconId', 'summonerLevel', 'revisionDate']
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
  
  def load_or_build_summoners_seen_filter
    summoners_seen = {}
    region_codes.each do |region, region_code|
      bf_path = @bloom_filter_factory.next_filepath region_code
      if File.exists? bf_path
        begin
          print "Loading summoners seen bloom filter for #{region} region from file #{bf_path}..."
          summoners_seen[region_code] = BloomFilter.load bf_path
          puts 'SUCCESS'
          next
        rescue
          puts 'FAILED'
        end
      end

      summoners_seen[region_code] = BloomFilter.new(:size => 10_000_000, :error_rate => 0.01)
    
      puts "Initialized new summoners seen bloom filter for #{region} region"
      print "Rebuilding #{region} region summoners seen bloom filter from processed summoner IDs..."
      @processed_output_factory.get_or_create_factory(region_code).each do |summoner_csv|
        CSV.foreach summoner_csv, :headers => true do |row|
          summoners_seen[region_code].insert row['name'].downcase.gsub(/\s/,'')
        end
      end
      puts 'DONE'
    end
    summoners_seen
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
          
          next if summoner_names.empty?
          path = "/api/lol/#{region_code}/v1.4/summoner/by-name/#{URI.escape summoner_names.join(',')}"
          
          output_filepath = @raw_output_factory.next_filepath region_code
          @data_collector.execute path, output_filepath
          
          puts "Wrote game summoner IDs to #{output_filepath}"
        end
      end
      
      File.delete data_filepath
      puts "Removed recent games file #{data_filepath}"
    end
    
    @summoners_seen = load_or_build_summoners_seen_filter
        
    num_headers = @processed_output_headers.count
    processed_values = {}
    @raw_output_factory.each do |region_code, raw_summoner_filepath|
      File.open(raw_summoner_filepath, 'r') do |f|
        raw_summoners = JSON.parse f.read
        raw_summoners.each do |summoner_name, summoner_values|
          values = @processed_output_headers.map { |key| summoner_values[key] }
          next if values.count { |val| !val.nil? } < num_headers
          next if @summoners_seen[region_code].include? summoner_name
          
          processed_values[region_code] ||= []
          processed_values[region_code] << values
          @summoners_seen[region_code].insert summoner_name
        end
      end
      
      File.delete raw_summoner_filepath
      puts "Removed raw summoner ID file #{raw_summoner_filepath}"
      
      if processed_values.count > SUMMONER_IDS_PER_FILE
        values_to_write = processed_values[region_code].slice! 0, SUMMONER_IDS_PER_FILE
        processed_filepath = @processed_output_factory.next_filepath region_code
        CSV.write processed_filepath, values_to_write, @processed_output_headers
        puts "Wrote #{SUMMONER_IDS_PER_FILE} summoner IDs to file #{processed_filepath}"
      end
    end
    
    region_codes.each do |region, region_code|
      unless processed_values[region_code].nil? || processed_values[region_code].empty?
        processed_filepath = @processed_output_factory.next_filepath region_code
        CSV.write processed_filepath, processed_values[region_code], @processed_output_headers
        puts "Wrote remaining summoner IDS to file #{processed_filepath}"
      end
      
      bf_path = @bloom_filter_factory.next_filepath region_code
      @summoners_seen[region_code].dump bf_path
      puts "Saved summoners seen bloom filter for region #{region_code} to #{bf_path}"
    end
  end
end