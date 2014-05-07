require 'fileutils'
require_relative './file_factory'

module FileFactory
  class DummyFileFactory < FileFactory
    # DummyFileFactory class only meant to be used with FileFactoryHierarchy
    def initialize(dir_path, filename, file_extension='')
      @dir = dir_path
      @filename = filename
      @file_extension = file_extension
      FileUtils.mkpath(dir_path)
    end
    
    def each
      filename = @filename
      filename += ".#{@file_extension}" unless @file_extension.empty?
      Dir.glob(File.join(@dir, filename)) { |f| yield f }
    end
    
    def next_filename
      filename = @filename
      filename += ".#{@file_extension}" unless @file_extension.empty?
      return filename
    end
  end
end