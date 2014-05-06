require 'rubygems'
require 'bloom-filter'
require_relative './file_factory/dummy_file_factory'
require_relative './file_factory/file_factory_hierarchy'
require_relative './file_factory/partitioned_file_factory'
require_relative './lol_constants'
require_relative './util/csv_utilities'

class SummonersSeenFilter
  include LolConstants
  
  def initialize
    @summoners_seen = {}
    @processed_output_path = File.expand_path('../../data/processed/summoner_ids', __FILE__)
    @processed_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @processed_output_path, 'summoner_ids', 'csv')
    @bloom_filter_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::DummyFileFactory, @processed_output_path, 'summoners_seen', 'bloom')
  end
  
  def load
    region_codes.each do |region, region_code|
      bf_path = @bloom_filter_factory.next_filepath region_code
      if File.exists? bf_path
        begin
          print "Loading summoners seen bloom filter for #{region} region from file #{bf_path}..."
          @summoners_seen[region_code] = BloomFilter.load bf_path
          puts 'SUCCESS'
          next
        rescue
          puts 'FAILED'
        end
      end

      @summoners_seen[region_code] = BloomFilter.new(:size => 10_000_000, :error_rate => 0.01)
    
      puts "Initialized new summoners seen bloom filter for #{region} region"
      print "Rebuilding #{region} region summoners seen bloom filter from processed summoner IDs..."
      @processed_output_factory.get_or_create_factory(region_code).each do |summoner_csv|
        CSV.foreach summoner_csv, :headers => true do |row|
          @summoners_seen[region_code].insert row['id']
        end
      end
      puts 'DONE'
    end
  end
  
  def save
    region_codes.each do |region, region_code|
      bf_path = @bloom_filter_factory.next_filepath region_code
      @summoners_seen[region_code].dump bf_path
      puts "Saved summoners seen bloom filter for region #{region_code} to #{bf_path}"
    end
  end
  
  def insert(region_code, summoner_id)
    @summoners_seen[region_code].insert summoner_id.to_s
  end
  
  def include?(region_code, summoner_id)
    @summoners_seen[region_code].include? summoner_id.to_s
  end
end