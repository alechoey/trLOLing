module FileFactory
  class FileFactory
    include Enumerable
        
    def next_filename(filename_prepend='')
      raise NotImplementedError, 'FileFactory is an abstract type and must be extended'
    end
    
    def next_filepath(dir_path='', filename_prepend='')
      File.join(@dir, next_filename(filename_prepend))
    end
  end
end