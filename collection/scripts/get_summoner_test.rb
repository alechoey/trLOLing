require_relative '../data_collector'

scraper = DataCollector.new('/api/lol/na/v1.3/summoner/by-name/RiotSchmick')
scraper.execute File.expand_path('../../../data/summoner_by_name', __FILE__)