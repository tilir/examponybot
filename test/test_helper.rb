# frozen_string_literal: true

#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Minspec test helper
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'minitest/reporters'
require 'handlers'
require 'pseudoapi'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

DB_PATH = 'smoke.db'

module PonyBotTestHelper
  def setup_test_env
    @handler = Handler.new(DB_PATH)
    @dbl = @handler.dbl
    @api = PseudoApi.new
    @prepod = PseudoTGUser.new(167_346_988, 'Tilir')
    @student1 = PseudoTGUser.new(10_002, 'student1')
    @student2 = PseudoTGUser.new(10_003, 'student2')
    @student3 = PseudoTGUser.new(10_004, 'student3')
    @student4 = PseudoTGUser.new(10_005, 'razdolb')
    @chat = PseudoChat.new(1)
  end

  def cleanup_test_env
    FileUtils.rm_f(DB_PATH)
  end

  def register_privuser
    event = PseudoMessage.new(@prepod, @chat, '/register')
    @handler.process_message(@api, event)
  end
end

module Minitest
  class Spec
    include PonyBotTestHelper
  end
end
