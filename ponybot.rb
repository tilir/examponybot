#!/usr/bin/env ruby
# frozen_string_literal: true

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
require_relative 'lib/handlers'

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
        next unless event.is_a?(Telegram::Bot::Types::Message)

        begin
          finish = handler.process_message(bot.api, event)
          break if finish && !first
        rescue Telegram::Bot::Exceptions::ResponseError => e
          if e.respond_to?(:error_code) && e.error_code == 403
            Logger.error("Telegram 403 for user_id=#{event.from&.id}: #{e.message}")
            next
          end

          Logger.error("Telegram API error: #{e.message}")
          Logger.error("Telegram API response: #{e.response}") if e.respond_to?(:response)
          next
        rescue StandardError => e
          Logger.error("Unhandled error while processing update: #{e.class}: #{e.message}")
          Logger.error(e.backtrace.join("\n"))
          next
        ensure
          first = false
        end
      end
    end
  end
end

# main program start
main
