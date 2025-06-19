#!/usr/bin/env ruby
# frozen_string_literal: true

#------------------------------------------------------------------------------
#
# Exam maker for ponybot
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Main file, start execution here
# example:
# ./ponymaker.rb -f 'your file' -o 'exam.db'
#
#------------------------------------------------------------------------------

require 'bundler/setup'
require 'optparse'
require_relative 'lib/importer'
require_relative 'lib/pseudoapi'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: ./ponymaker.rb -f questions.txt -o exam.db'

  opts.on('-fFILE', '--file=FILE', 'Input question file') do |f|
    options[:file] = f
  end

  opts.on('-oDB', '--output=DB', 'Output database file') do |db|
    options[:db] = db
  end
end.parse!

unless options[:file] && options[:db]
  warn 'Please specify input file (-f) and data base (-o)'
  exit 1
end

handler = Handler.new(options[:db])
api = PseudoApi.new
prepod = PseudoTGUser.new(167_346_988, 'Tilir')
chat = PseudoChat.new(1)

register_event = PseudoMessage.new(prepod, chat, '/register')
handler.process_message(api, register_event)

importer = QuestionImporter.new(
  filename: options[:file],
  handler: handler,
  api: api,
  prepod: prepod,
  chat: chat
)

importer.import!
puts "Import done: #{options[:db]}"
