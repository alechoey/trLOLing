module FileFactory
  class FileFactory
    include Enumerable
        
    def next_filename
      raise NotImplementedError, 'FileFactory is an abstract type and must be extended'
    end
    
    def next_filepath(dir_path='')
      File.join(@dir, next_filename)
    end
  end
end