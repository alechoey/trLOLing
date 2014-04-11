require 'fileutils'
require_relative './file_factory'

module FileFactory
  class PartitionedFileFactory < FileFactory       
    def initialize(dir_path, filename, file_extension='')
      @dir = dir_path
      @filename = filename
      @file_extension = file_extension
      FileUtils.mkpath(dir_path)
      
      max_partition_number = self.map do |partition_filename|
        get_partition_number_from_filename partition_filename
      end.max
      @partition_number = (max_partition_number || -1) + 1
    end
    
    def each
      filename_pattern = "#{@filename}-[0-9]*#{@file_extension}"
      Dir.foreach @dir do |partition_filename|
        next unless File.fnmatch? filename_pattern, partition_filename
        yield File.join @dir, partition_filename
      end
    end
    
    def get_partition_number_from_filename(partition_filename)
      filename_pattern = %r{#{@filename}\-([0-9]+)#{'\.' + @file_extension unless @file_extension.empty?}$}
      return 0 unless partition_filename =~ filename_pattern
      $1.to_i
    end
    
    def next_filename
      filename = "#{@filename}-#{@partition_number}"
      filename += ".#{@file_extension}" unless @file_extension.empty?
      @partition_number += 1
      return filename
    end
  end
end