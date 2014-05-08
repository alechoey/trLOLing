require 'json'
require_relative './file_factory/file_factory_hierarchy'
require_relative './file_factory/partitioned_file_factory'
require_relative './file_factory/prepended_dummy_file_factory'
require_relative './file_factory/time_stamped_file_factory'
require_relative './lol_api'
require_relative './lol_constants'
require_relative './summoners_seen_filter'

class GameProcessor
  include LolConstants
  def initialize(api_keys=[ENV['LOL_API_KEY']], regions=region_codes.values)
    @input_path = File.expand_path('../../data/raw/games', __FILE__)
    @incomplete_output_path = File.expand_path('../../data/processed/games/incomplete', __FILE__)
    @complete_output_path = File.expand_path('../../data/processed/games/complete', __FILE__)
    @raw_summoner_ids_path = File.expand_path('../../data/raw/summoner_ids', __FILE__)

    @input_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::TimeStampedFileFactory, @input_path, 'games', 'json')
    @incomplete_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PrependedDummyFileFactory, @incomplete_output_path, 'game', 'json')
    @complete_output_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PrependedDummyFileFactory, @complete_output_path, 'game', 'json')
    @raw_summoner_ids_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PartitionedFileFactory, @raw_summoner_ids_path, 'summoner_ids', 'json')
    
    @api = LolApi.new api_keys
    @regions = regions
    @summoners_seen = SummonersSeenFilter.new
  end
  
  def process
    @regions.each do |region_code|
      @input_factory.get_or_create_factory(region_code).each do |data_filepath|
        File.open data_filepath, 'r' do |in_file|
          begin
            json = JSON.parse(in_file.read)
            summoner_id = json['summonerId']
            games = json['games']
          rescue JSON::ParserError
            puts "[ERROR] There were problems with parsing the file #{data_filepath}"
            next
          end
        
          next if games.nil? || summoner_id.nil?
          games.each do |game|
            game_id = game['gameId']
            game_json = { summoner_id => game }
            game_json['summonerCount'] ||= 1
            game_output_path = @incomplete_output_factory.next_filepath(region_code, game_id.to_s)

            if File.exists? game_output_path
              File.open(game_output_path, 'r') do |out_file|
                merge_json = JSON.parse(out_file.read)
                game_json.merge! merge_json
                game_json['summonerCount'] = game_json.reject { |k,v| k == 'summonerCount' }.keys.uniq.count
              end
            end
          
            summoner_count = game_json['summonerCount']
            if summoner_count == 10
              File.delete game_output_path
              puts "Removed incomplete game file #{game_output_path}"
              game_output_path = @complete_output_factory.next_filepath(region_code, game_id.to_s)
            end

            File.open(game_output_path, 'w') do |out_file|
              game_output = JSON.pretty_generate game_json
              out_file.write game_output
              if summoner_count > 1
                puts "Wrote updated game file to #{game_output_path}"
              else
                puts "Wrote incomplete game new file to #{game_output_path}"
              end
            end
          end
        end
      
        File.delete data_filepath
        puts "Removed raw games file #{data_filepath}"
      end
    end
    
    summoner_ids = Hash.new { Array.new }
    @summoners_seen.load
    
    @regions.each do |region_code|
      @incomplete_output_factory.get_or_create_factory(region_code).each do |incomplete_filepath|
        File.open incomplete_filepath, 'r' do |in_file|
          json = JSON.parse(in_file.read)
          next unless json['summonerCount'] > 1
          summoner_objects = json.select { |k,v| k =~ /[0-9]+/ }.values.first['fellowPlayers']
          next if summoner_objects.nil?
          new_summoner_ids = summoner_objects.map { |summoner| summoner['summonerId'] }.reject { |summoner_id| @summoners_seen.include? region_code, summoner_id }
          new_summoner_ids.map { |summoner_id| @summoners_seen.insert region_code, summoner_id }
          summoner_ids[region_code] += new_summoner_ids
        
          while summoner_ids[region_code].count > 40
            @api.get_summoners_by_id summoner_ids[region_code].slice!(0, 40), region_code, @raw_summoner_ids_factory.next_filepath(region_code)
          end
        end
      end
    end
    
    summoner_ids.each do |region_code, summoner_ids|
      while summoner_ids[region_code].count > 40
        @api.get_summoners_by_id summoner_ids[region_code].slice!(0, 40), region_code, @raw_summoner_ids_factory.next_filepath(region_code)
      end
    end
  end
end