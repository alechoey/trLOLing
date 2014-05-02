require 'json'
require 'rubygems'
require 'bloom-filter'
require_relative './file_factory/dummy_file_factory'
require_relative './file_factory/file_factory_hierarchy'
require_relative './file_factory/partitioned_file_factory'
require_relative './lol_constants'
require_relative './util/csv_utilities'

class SummonerIdProcessor
  include LolConstants
  SUMMONER_IDS_PER_FILE = 10000
  
  def initialize
    @raw_output_path = File.expand_path('../../data/raw/summoner_ids', __FILE__)
    @processed_output_path = File.expand_path('../../data/processed/summoner_ids', __FILE__)
    
    @raw_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @raw_output_path, 'summoner_ids', 'json')
    @processed_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @processed_output_path, 'summoner_ids', 'csv')
    @bloom_filter_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::DummyFileFactory, @processed_output_path, 'summoners_seen', 'bloom')
    
    @processed_output_headers = ['id', 'name', 'profileIconId', 'summonerLevel', 'revisionDate']
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
    @summoners_seen = load_or_build_summoners_seen_filter
        
    num_headers = @processed_output_headers.count
    processed_values = {}
    @raw_output_factory.each do |region_code, raw_summoner_filepath|
      puts "Opening #{raw_summoner_filepath}"
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