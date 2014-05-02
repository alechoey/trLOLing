require_relative './file_factory'

module FileFactory
  class DummyFileFactory
    # DummyFileFactory class only meant to be used with FileFactoryHierarchy
    def initialize(dir_path, filename, file_extension='')
      @dir = dir_path
      @filename = filename
      @file_extension = file_extension
      FileUtils.mkpath(dir_path)
    end
    
    def each(prepended=false)
      filename = @filename
      filename += ".#{@file_extension}" unless @file_extension.empty?
      filename = "*#{filename}" if prepended
      Dir.glob(File.join(@dir, filename)) { |f| yield f }
    end
    
    def next_filename(filename_prepend='')
      filename = @filename
      filename = "#{filename_prepend}_#{filename}" unless filename_prepend.empty?
      filename += ".#{@file_extension}" unless @file_extension.empty?
      return filename
    end
  end
end