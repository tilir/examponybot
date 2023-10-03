class Logger
  attr_accessor :verbose
  def initialize val
    @@verbose = val
  end
  def to_s
    "#{@@verbose}"
  end
end

def main
  l1 = Logger.new(1)
  puts l1

  l2 = Logger.new(2)
  puts l1

end

main