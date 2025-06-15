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
  attr_accessor :text
  def send_message(chat_id:, text:)
    @text = "#{chat_id} : #{text}"
  end
end

class PseudoUser
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
