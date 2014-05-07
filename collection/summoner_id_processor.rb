require 'json'
require_relative './file_factory/file_factory_hierarchy'
require_relative './file_factory/partitioned_file_factory'
require_relative './summoners_seen_filter'

class SummonerIdProcessor
  SUMMONER_IDS_PER_FILE = 10000
  
  def initialize
    @raw_output_path = File.expand_path('../../data/raw/summoner_ids', __FILE__)
    @processed_output_path = File.expand_path('../../data/processed/summoner_ids', __FILE__)
    
    @raw_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @raw_output_path, 'summoner_ids', 'json')
    @processed_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @processed_output_path, 'summoner_ids', 'csv')
    @processed_output_headers = ['id', 'name', 'profileIconId', 'summonerLevel', 'revisionDate']
    @summoners_seen = SummonersSeenFilter.new
  end
  
  def process
    @summoners_seen.load
        
    num_headers = @processed_output_headers.count
    processed_values = {}
    @raw_output_factory.each do |region_code, raw_summoner_filepath|
      puts "Opening #{raw_summoner_filepath}"
      File.open(raw_summoner_filepath, 'r') do |f|
        raw_summoners = JSON.parse f.read
        raw_summoners.each do |summoner_name, summoner_values|
          values = @processed_output_headers.map { |key| summoner_values[key] }
          summoner_id = summoner_values['id']
          next if summoner_id.nil?
          next if values.count { |val| !val.nil? } < num_headers
          next if @summoners_seen.include? region_code, summoner_id
          
          processed_values[region_code] ||= []
          processed_values[region_code] << values
          @summoners_seen.insert region_code, summoner_id
        end
      end
      
      File.delete raw_summoner_filepath
      puts "Removed raw summoner ID file #{raw_summoner_filepath}"
      
      if processed_values[region_code].count > SUMMONER_IDS_PER_FILE
        values_to_write = processed_values[region_code].slice! 0, SUMMONER_IDS_PER_FILE
        processed_filepath = @processed_output_factory.next_filepath region_code
        CSV.write processed_filepath, values_to_write, @processed_output_headers
        puts "Wrote #{SUMMONER_IDS_PER_FILE} summoner IDs to file #{processed_filepath}"
      end
    end
    
    processed_values.keys.each do |region_code|
      unless processed_values[region_code].empty?
        processed_filepath = @processed_output_factory.next_filepath region_code
        CSV.write processed_filepath, processed_values[region_code], @processed_output_headers
        puts "Wrote remaining summoner IDS to file #{processed_filepath}"
      end
    end
    
    @summoners_seen.save
  end
end