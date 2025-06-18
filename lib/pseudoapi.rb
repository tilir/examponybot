#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Pseudo telegram API for unit test purposes
#
#------------------------------------------------------------------------------

class PseudoApi
  attr_reader :text
  
  def initialize
    @text = ""
  end
  
  def text!
    @text.tap { @text = "" }
  end

  def send_message(chat_id:, text:)
    @text << "#{chat_id} : #{text}\n"
    Logger.print @text
  end
end

class PseudoTGUser
  attr_accessor :id
  attr_accessor :username
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
  attr_accessor :from
  attr_accessor :chat
  attr_accessor :text
  def initialize(from, chat, text)
    @from = from
    @chat = chat
    @text = text
  end
end
