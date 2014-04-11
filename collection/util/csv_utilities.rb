require 'csv'

class CSV
  def self.write(filename, objs, header=[])
    open filename, 'wb' do |csv|
      csv << header unless header.empty?
      objs.each { |obj| csv << obj }
    end
  end
end