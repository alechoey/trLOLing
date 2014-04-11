require_relative './file_factory/time_stamped_file_factory'

# Write timestamped files for data in the same directory

class RawOutputter
  def initialize(dir_path, filename='', extension='')
    @factory = FileFactory::TimeStampedFileFactory.new(dir_path, filename, extension)
  end
  
  def write(output)
    output_path = @factory.next_filepath
    File.open(output_path, 'w') do |f|
      f.write output
    end
    output_path
  end
end