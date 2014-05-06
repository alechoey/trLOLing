require 'fileutils'
require_relative './file_factory'

module FileFactory
  class TimeStampedFileFactory < FileFactory
    def initialize(dir_path, filename, file_extension='')
      @dir = dir_path
      @filename = filename
      @file_extension = file_extension
      FileUtils.mkpath(dir_path)
    end
    
    def each
      filename_pattern = "*#{@filename}*#{@file_extension}"
      Dir.foreach @dir do |filename|
        next unless File.fnmatch? filename_pattern, filename
        yield File.join @dir, filename
      end
    end
    
    def next_filename
      time_string = Time.now.strftime '%Y%m%d%H%M%S%L'
      output_name = time_string
      output_name += "-#{@filename}" if !@filename.empty?
      output_name += ".#{@file_extension}" if !@file_extension.empty?
      output_name
    end
  end
end