require 'json'
require 'optparse'
require_relative '../file_factory/file_factory_hierarchy'
require_relative '../file_factory/prepended_dummy_file_factory'
require_relative '../file_factory/time_stamped_file_factory'
require_relative '../lol_constants'
require_relative '../util/csv_utilities'

include LolConstants

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: convert_games_to_csv.rb --[in]complete"
  options[:complete] = true
  
  opts.on('-i', '--incomplete') do
    options[:complete] = false
  end
  
  opts.on('-c', '--complete') do
    options[:complete] = true
  end  
end.parse!

@input_path = File.expand_path('../../../data/processed/games', __FILE__)
@output_path = File.expand_path("../../../data/final/#{'in' unless options[:complete]}complete", __FILE__)

@input_factory = FileFactory::FileFactoryHierarchy.new(FileFactory::PrependedDummyFileFactory, @input_path, 'game', 'json')
@output_factory = FileFactory::TimeStampedFileFactory.new(@output_path, 'games', 'csv')

@rows = []
@header = []

if options[:complete]
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
else
  @headers = ['championId']
  @stat_headers = []
end

1.upto 2 do |team_n|
  1.upto 5 do |summoner_n|
    @headers.each do |header|
      @header << "team#{team_n}summoner#{summoner_n}#{header}"
    end
    
    if options[:complete]
      @stat_headers.each do |header|
        @header << "team#{team_n}summoner#{summoner_n}#{header}"
      end
    end
  end
end
@header << 'team1summoner1win' unless options[:complete]

def process_file(region_code, data_filepath, complete=true)
  File.open data_filepath, 'r' do |in_file|
    begin
      game_json = JSON.parse(in_file.read)
    rescue JSON::ParserError
      puts "[ERROR] There were problems with parsing the file #{data_filepath}"
      return
    end
    
    summoners = game_json.reject { |key, value| key == 'summonerCount' }.values
    unless complete
      summoner = summoners.first
      return if summoner.nil?
      summoners = summoner['fellowPlayers']
      return if summoners.nil?
      summoners << summoner
    end
    
    return unless summoners.count == 10
    
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
      
        if complete
          @stat_headers.each do |key|
            row << summoner['stats'][key]
          end
        end
      end
    end
    
    unless complete
      win = summoner['stats']['win']
      win = !win if summoner['teamId'] == 200
      row << win
    end
    
    @rows << row
  end
end

region_codes.values.each do |region_code|
  @input_factory.get_or_create_factory("complete/#{region_code}").each do |data_filepath|
    process_file(region_code, data_filepath, options[:complete])
  end
  unless options[:complete]
    @input_factory.get_or_create_factory("incomplete/#{region_code}").each do |data_filepath|
      process_file(region_code, data_filepath, options[:complete])
    end
  end
end

CSV.write @output_factory.next_filepath, @rows, @header