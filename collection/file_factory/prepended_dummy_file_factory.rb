require_relative './dummy_file_factory'
require_relative './file_factory'

module FileFactory
  class PrependedDummyFileFactory < DummyFileFactory
    alias :unprepended_filename :next_filename
    
    def each
      filename = "*#{@filename}"
      filename += ".#{@file_extension}" unless @file_extension.empty?
      Dir.glob(File.join(@dir, filename)) { |f| yield f }
    end
        
    def next_filename(filename_prepend='')
      filename = unprepended_filename
      filename = "#{filename_prepend}_#{filename}" unless filename_prepend.empty?
      filename
    end
  end
end