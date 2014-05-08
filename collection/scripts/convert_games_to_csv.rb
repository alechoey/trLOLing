require 'json'
require_relative '../file_factory/file_factory_hierarchy'
require_relative '../file_factory/prepended_dummy_file_factory'
require_relative '../file_factory/time_stamped_file_factory'
require_relative '../lol_constants'
require_relative '../util/csv_utilities'

include LolConstants

@input_path = File.expand_path('../../../data/processed/games/complete', __FILE__)
@output_path = File.expand_path('../../../data/final', __FILE__)

@input_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PrependedDummyFileFactory, @input_path, 'game', 'json')
@output_factory = FileFactory::TimeStampedFileFactory.new(@output_path, 'games', 'csv')

@headers = ['championId', 'spell1', 'spell2']
@stat_headers = [
  'level',
  'goldEarned',
  'numDeaths',
  'turretsKilled',
  'minionsKilled',
  'championsKilled',
  'goldSpent',
  'totalDamageDealt',
  'totalDamageTaken',
  'doubleKills',
  'killingSprees',
  'largestKillingSpree',
  'team',
  'win',
  'neutralMinionsKilled',
  'largestMultiKill',
  'physicalDamageDealtPlayer',
  'magicDamageDealtPlayer',
  'physicalDamageTaken',
  'magicDamageTaken',
  'largestCriticalStrike',
  'timePlayed',
  'totalHeal',
  'totalUnitsHealed',
  'assists',
  'item0',
  'item1',
  'item2',
  'item3',
  'item4',
  'item6',
  'magicDamageDealtToChampions',
  'physicalDamageDealtToChampions',
  'totalDamageDealtToChampions',
  'trueDamageDealtPlayer',
  'trueDamageDealtToChampions',
  'trueDamageTaken',
  'wardPlaced',
  'neutralMinionsKilledYourJungle',
  'totalTimeCrowdControlDealt',
]
@rows = []
@header = []
1.upto 2 do |team_n|
  1.upto 5 do |summoner_n|
    @headers.each do |header|
      @header << "team#{team_n}summoner#{summoner_n}#{header}"
    end
    @stat_headers.each do |header|
      @header << "team#{team_n}summoner#{summoner_n}#{header}"
    end
  end
end

@input_factory.each do |region_code, data_filepath|
  File.open data_filepath, 'r' do |in_file|
    begin
      game_json = JSON.parse(in_file.read)
    rescue JSON::ParserError
      puts "[ERROR] There were problems with parsing the file #{data_filepath}"
      next
    end
  
    summoners = game_json.reject { |key, value| key == 'summonerCount' }.values
    next if summoners.count < 10
    game_vals = {}
    summoners.group_by { |summoner| summoner['teamId'] }.each do |team_id, summoners|
      game_vals[team_id]  = summoners.sort_by { |summoner| summoner['championId'] }
    end
  
    row = []
    [100, 200].each do |team_id|
      summoners = game_vals[team_id]
      summoners.each do |summoner|
        @headers.each do |key|
          row << summoner[key]
        end
      
        @stat_headers.each do |key|
          row << summoner['stats'][key]
        end
      end
    end
    @rows << row
  end
end

CSV.write @output_factory.next_filepath, @rows, @header