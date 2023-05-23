#!/usr/bin/env ruby
#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Main file, start execution here
# example:
# ./ponybot.rb -t 'your token' -d 'exam.db'
#
#------------------------------------------------------------------------------

require 'optparse'
require 'telegram/bot'
require_relative './lib/handlers'

def parse_options
  options = {}
  options[:dbname] = "exam.db"

  OptionParser.new do |opts|
    opts.banner = "Usage: ./ponybot.rb [options]"

    opts.on("-t", "--token TOKEN", "Your bot token (mandatory)") do |v|
      options[:token] = v
    end

    opts.on("-b", "--database NAME", "Database name. Default: #{options[:dbname]}.") do |v|
      options[:dbname] = v
    end

    opts.on("-v", "--[no-]verbose", "Run verbosely. No default value.") do |v|
      options[:verbose] = v
    end

    opts.on("-h", "--help", "Prints this help.") do
      puts opts
      exit
    end
  end.parse!

  p options if options[:verbose]
  raise "You need to specify token" if options[:token].nil?

  options
end

def main
  options = parse_options
  handler = Handler.new(options[:dbname], options[:verbose])
  Telegram::Bot::Client.run(options[:token]) do |bot|
    finish = false
    bot.listen do |event|
      finish = handler.process_message(bot, event) if event.class == Telegram::Bot::Types::Message
    end
    break if finish
  end
  handler.shutdown
end

# main program start
main
