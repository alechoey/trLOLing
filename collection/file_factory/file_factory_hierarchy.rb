require 'forwardable'
require 'pathname'
require_relative './file_factory'

module FileFactory
  class FileFactoryHierarchy < FileFactory
    extend Forwardable
      
    def initialize(file_factory_class, dir_path, filename, file_extension='')
      @file_factory_class = file_factory_class
      @root_dir = Pathname.new dir_path
      @dir = Pathname.new dir_path
      @filename = filename
      @file_extension = file_extension
      
      @file_factories = {}
      Dir.glob(File.join @root_dir, '**/*/') do |dir|
        dir_str = dir.chomp '/'
        @file_factories[dir_str] ||= @file_factory_class.new(dir_str, @filename, @file_extension)
      end
      find_or_create_current_file_factory
    end
    
    def get_or_create_factory(dir_path)
      tmp_curr = @current_file_factory
      to_dir dir_path
      result = @current_file_factory
      @current_file_factory = tmp_curr
      result
    end
    
    def to_dir(dir_path)
      @dir = @root_dir.join dir_path
      find_or_create_current_file_factory
    end
    
    def each
      @file_factories.each do |dir, file_factory|
        file_factory.each { |file| yield Pathname.new(dir).relative_path_from(@root_dir).to_s, file }
      end
    end

    def_delegator :@current_file_factory, :next_filename
    
    def next_filepath(dir_path='', *args)
      super if dir_path.empty?
      filename = next_filename *args
      File.join @root_dir, dir_path, filename
    end    
    
    private
    def find_or_create_current_file_factory
      @file_factories[@dir.to_s] ||= @file_factory_class.new(@dir, @filename, @file_extension)
      @current_file_factory = @file_factories[@dir.to_s]
    end
  end
end