require 'csv'
require_relative './data_collector'
require_relative './file_factory/file_factory_hierarchy'
require_relative './file_factory/partitioned_file_factory'
require_relative './file_factory/time_stamped_file_factory'

class GameScraper
  def initialize
    @input_path = File.expand_path('../../data/processed/summoner_ids', __FILE__)
    @output_path = File.expand_path('../../data/raw/games', __FILE__)
    
    @data_collector = DataCollector.new
    @input_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @input_path, 'summoner_ids', 'csv')
    @output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::TimeStampedFileFactory, @output_path, 'games', 'json')
  end
  
  def process
    @input_factory.each do |region_code, filename|
      puts "Opening summoner ID file #{filename}"
      CSV.foreach filename, :headers => true do |row|
        path = "/api/lol/#{region_code}/v1.3/game/by-summoner/#{row['id']}/recent"
        output_filepath = @output_factory.next_filepath region_code
        @data_collector.execute path, output_filepath
        
        puts "Wrote recent games for summoner #{row['name']} to #{output_filepath}"
      end
    end
  end
end