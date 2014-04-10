require 'time'

# Write timestamped files for data in the same directory

class RawOutputter
  def initialize(directory, filename='', extension='')
    @directory = directory
    @filename = filename
    @extension = extension
    FileUtils.mkpath(directory)
  end
  
  def write(output)
    time_string = Time.now.strftime '%Y%m%d%H%M%S%L'
    output_name = time_string
    output_name += "-#{@filename}" if !@filename.empty?
    output_name += ".#{@extension}" if !@extension.empty?
    File.open(File.join(@directory, output_name), 'w') do |f|
      f.write output
    end
    return output_name
  end
end