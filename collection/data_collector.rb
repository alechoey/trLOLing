require 'json'
require 'time'
require 'uri'
require 'rubygems'
require 'curb'

class DataCollector
  API_HOSTNAME = 'https://prod.api.pvp.net'
  TIME_INTERVAL = 1.5
  
  def initialize(api_key=ENV['LOL_API_KEY'])
    @api_key = api_key
    @last_request_at = nil
  end
    
  def execute(path, output_path=nil, path_args={})
    request_url = URI.join URI(API_HOSTNAME), path

    www_path_args = URI.encode_www_form path_args.merge(:api_key => @api_key)
    request_url.query = www_path_args
    
    send_request request_url
    write_request_body output_path if output_path
    
    @data.body_str
  end

  private
  
  def send_request(request_url)
    unless @last_request_at.nil?
      time_difference = Time.now - @last_request_at
      sleep TIME_INTERVAL if time_difference < TIME_INTERVAL
    end
    @data = Curl::Easy.perform(request_url.to_s)
    @last_request_at = Time.now
  end
  
  def write_request_body(output_path=nil)
    return unless output_path
    File.open(output_path, 'wb') do |f|
      begin
        json = JSON.parse @data.body_str
        f.write JSON.pretty_generate json
      rescue
        puts "Was unable to parse and write JSON to file #{output_path}"
      end
    end
  end
end