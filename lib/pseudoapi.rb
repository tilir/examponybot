# frozen_string_literal: true

#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Pseudo telegram API for unit test purposes
# It also is used for test importer so it lives here in lib
#
#------------------------------------------------------------------------------

require_relative 'logger'

# Configure once at the beginning (disable for clean test output)
Logger.set_verbose(false)

class PseudoApi
  attr_reader :text

  def initialize
    @text = String.new
  end

  def text!
    @text.tap { @text = String.new }
  end

  def send_message(chat_id:, text:)
    @text << "#{chat_id} : #{text}\n"
    Logger.print @text
  end
end

class PseudoTGUser
  attr_accessor :id, :username

  def initialize(id, username)
    @id = id
    @username = username
  end
end

class PseudoChat
  attr_accessor :id

  def initialize(id)
    @id = id
  end
end

class PseudoMessage
  attr_accessor :from, :chat, :text

  def initialize(from, chat, text)
    @from = from
    @chat = chat
    @text = text
  end
end
