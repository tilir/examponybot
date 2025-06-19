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
  Logger.set_verbose(options[:verbose])

  Telegram::Bot::Client.run(options[:token]) do |bot|
    Handler.new(options[:dbname]) do |handler|
      bot.listen do |event|
        next unless event.is_a?(Telegram::Bot::Types::Message)

        begin
          if handler.process_message(bot.api, event)
            Logger.print('Received exit command, shutting down...')
            break
          end
        rescue StandardError => e
          Logger.error("Error processing message: #{e.message}")
          bot.api.send_message(
            chat_id: event.chat.id,
            text: "Error processing message: #{e.message}"
          )
        end
      end
    end
  end
rescue DBLayerError => e
  puts "[[DBLayerError]] #{e.message}"
  Logger.error("Database error: #{e.backtrace.join("\n")}")
rescue Telegram::Bot::Exceptions::ResponseError => e
  puts "[[TelegramAPIError]] #{e.message}"
  Logger.error("Telegram API error: #{e.response}")
end

# main program start
main
