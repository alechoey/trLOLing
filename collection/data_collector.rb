require 'json'
require 'uri'
require 'rubygems'
require 'curb'

class DataCollector
  API_HOSTNAME = 'https://prod.api.pvp.net'
  
  def initialize(path, path_args={}, api_key=ENV['LOL_API_KEY'])
    @api_key = api_key
    @path_args = path_args
    @request_url = URI.join URI(API_HOSTNAME), path

    www_path_args = URI.encode_www_form path_args.merge(:api_key => @api_key)
    @request_url.query = www_path_args
  end
    
  def execute(output_path=nil)
    send_request
    write_request_body output_path
  end

  private
  
  def send_request
    @data = Curl::Easy.perform(@request_url.to_s)
  end
  
  def write_request_body(output_path=nil)
    return unless output_path
    File.open(output_path, 'wb') do |f|
      json = JSON.parse! @data.body_str
      f.write JSON.pretty_generate json
    end
  end
end