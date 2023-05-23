#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Bot handlers
#
#------------------------------------------------------------------------------

require_relative './dblayer'

class Handler
  def initialize(dbname, verbose)
    @dbl = DBLayer.new(dbname, verbose)
    @dbname = dbname
    @verbose = verbose
  end

  def register_user(bot, tguser, name)
    name = "#{tguser.username}" if name.nil? or name == ""

    # first user added with pedagogical priviledges
    @dbl.add_user(tguser, 0, name) if @dbl.users_empty?

    # subsequent users added with student privileges
    dbuser = @dbl.get_user_by_id(tguser.id)
    if (dbuser.nil?)
      @dbl.add_user(tguser, 1, name)
      bot.api.send_message(chat_id: tguser.id, text: "Registered as #{name}")
    else
      bot.api.send_message(chat_id: tguser.id, text: "You were already registered as #{dbuser.username}")
    end
  end

  # returns if we need to exit
  def process_message(bot, message)
    p message.text
    return false if message.text.nil?
    return false if not message.text.start_with?('/')

    re = '(/\w+)\s*(\w*)'
    matches = message.text.match(re).to_a
    command = matches[1]
    rest = matches[2]
    tguser = message.from
    tgchat = message.chat
    p "C: #{command} from <#{tguser.id}> in chat <#{tgchat.id}> with rest <#{rest}>" if @verbose
    case command
    when '/register'
      register_user(bot, tguser, rest)

      # close and reload database: important before ctrl-break
    when '/reload'
      @dbl.close
      @dbl = DBLayer.new(@dbname, @verbose)
      # TODO: can not make it work: all it reads afterwards is /exit again and again
    when '/exit'
      return true
    end
    return false
  end

  def shutdown
    @dbl.close
  end
end
