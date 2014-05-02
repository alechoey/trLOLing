require_relative './data_collector'

class LolApi
  def initialize
    @data_collector = DataCollector.new
  end
  
  def get_summoner_ids_by_name(summoner_names=[], region_code='na', output_filepath='')
    return if summoner_names.empty?
    path = "/api/lol/#{region_code}/v1.4/summoner/by-name/#{URI.escape summoner_names.join(',')}"
    @data_collector.execute path, output_filepath
    puts "Wrote summoner IDs to #{output_filepath}"
  end
  
  def get_summoners_by_id(summoner_ids=[], region_code='na', output_filepath='')
    return if summoner_ids.empty?
    path = "/api/lol/#{region_code}/v1.4/summoner/#{URI.escape summoner_ids.join(',')}"
    @data_collector.execute path, output_filepath
    puts "Wrote summoner IDs to #{output_filepath}"
  end
end