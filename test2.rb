class Logger
  def self.set_verbose
    puts @@verbose
    @@verbose = 1
  end
  def self.print message
    @@verbose ||= 0
    puts @@verbose
    if @@verbose == 1
      puts message 
    end
  end
end

def main
  Logger.print "bla"

  Logger.set_verbose

  Logger.print "blabla"

  pp "bla"

end

main