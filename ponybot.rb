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

require 'bundler/setup'
require 'optparse'
require 'telegram/bot'
require_relative './lib/handlers'

def parse_options
  options = {}
  options[:dbname] = 'exam.db'

  OptionParser.new do |opts|
    opts.banner = 'Usage: ./ponybot.rb [options]'

    opts.on('-t', '--token TOKEN', 'Your bot token (mandatory)') do |v|
      options[:token] = v
    end

    opts.on('-b', '--database NAME', "Database name. Default: #{options[:dbname]}.") do |v|
      options[:dbname] = v
    end

    opts.on('-v', '--[no-]verbose', 'Run verbosely. No default value.') do |v|
      options[:verbose] = v
    end

    opts.on('-h', '--help', 'Prints this help.') do
      puts opts
      exit
    end
  end.parse!

  p options if options[:verbose]
  raise 'You need to specify token' if options[:token].nil?

  options
end

def main
  options = parse_options
  Logger.set_verbose options[:verbose]
  Handler.new(options[:dbname]) do |handler|
    finish = false
    first = true
    Telegram::Bot::Client.run(options[:token]) do |bot|
      bot.listen do |event|
        finish = handler.process_message(bot.api, event) if event.class == Telegram::Bot::Types::Message
        break if finish and !first

        first = false
      end
    end
  end
rescue DBLayerError => e
  puts "[[DBLayerError]] #{e}"
end

# main program start
main
