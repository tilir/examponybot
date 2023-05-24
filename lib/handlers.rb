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

  def check_user(bot, dbuser)
    if (dbuser.nil?)
      bot.api.send_message(chat_id: tguser.id, text: "Please register to exam")
      return -1
    end
    return 0
  end

  def check_priv_user(bot, dbuser)
    return -1 if (check_user(bot, dbuser) == -1)

    if (dbuser.privlevel != 0)
      bot.api.send_message(chat_id: tguser.id, text: "Not enough priviledges for the command")
      return -1
    end
    return 0
  end

  # Priviledged part

  def all_users(bot, tguser)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(bot, dbuser) == -1)

    allu = @dbl.all_users
    bot.api.send_message(chat_id: tguser.id, text: "--- all users ---")
    allu.each do |usr|
      bot.api.send_message(chat_id: tguser.id, text: "#{usr.userid} #{usr.username} #{usr.privlevel}")
    end
    bot.api.send_message(chat_id: tguser.id, text: "---")
  end

  def add_question(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(bot, dbuser) == -1)

    p "add_question: #{rest}" if @verbose
    re = '(\d+)\s+(\d+)\s+(.+)'
    m = rest.match(re).to_a
    n = m[1]
    v = m[2]
    t = m[3]

    p "add_question: #{n} #{v} #{t}" if @verbose
    @dbl.add_question(n, v, t)
  end

  def all_questions(bot, tguser)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(bot, dbuser) == -1)

    allq = @dbl.all_questions
    bot.api.send_message(chat_id: tguser.id, text: "--- all questions ---")
    allq.each do |qst|
      bot.api.send_message(chat_id: tguser.id, text: "#{qst.number} #{qst.variant} #{qst.text}")
    end
    bot.api.send_message(chat_id: tguser.id, text: "---")

    nn = @dbl.n_questions
    nv = @dbl.n_variants
    if (nn * nv != allq.length)
      bot.api.send_message(chat_id: tguser.id, text: "Warning: #{nn} * #{nv} != #{allq.length}")
    end
  end

  def start_exam(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(bot, dbuser) == -1)

    allu = @dbl.all_users
    nn = @dbl.n_questions
    nv = @dbl.n_variants
    # set exam to started state (state 1)
    # determine which user have which variant and send
    # also write this data to userquestions table
  end

  def start_review(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(bot, dbuser) == -1)
    # set exam to review state (state 2)
    # determine which user have which review and send
    # also write this data to userreviews table
  end

  def set_grades(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(bot, dbuser) == -1)
   # set exam to final state (state 3)
   # lookup all review records for all registered users
   # send back grades
 end

  # Non-priviledged part

  def register_user(bot, tguser, name)
    name = "#{tguser.username}" if name.nil? or name == ""
    p "register_user: #{name}" if @verbose

    # first user added with pedagogical priviledges
    if @dbl.users_empty?
      @dbl.add_user(tguser, 0, name)
      bot.api.send_message(chat_id: tguser.id, text: "Registered (priviledged) as #{name}")
      return
    end

    # subsequent users added with student privileges
    dbuser = @dbl.get_user_by_id(tguser.id)
    if (dbuser.nil?)
      @dbl.add_user(tguser, 1, name)
      bot.api.send_message(chat_id: tguser.id, text: "Registered as #{name}")
    else
      bot.api.send_message(chat_id: tguser.id, text: "You were already registered as #{dbuser.username}")
    end
  end

  def send_answer(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(bot, dbuser) == -1)
    # lookup userquestions id
    # record answer
  end

  def lookup_answer(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(bot, dbuser) == -1)
    # lookup userquestions id
    # send answer back to user
  end

  def send_review(bot, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(bot, dbuser) == -1)
    # lookup userreviews id
    # record review and grade
  end

  # returns true if we need to exit
  def process_message(bot, message)
    p "process_message: #{message.text}" if @verbose
    return false if message.text.nil?
    return false if not message.text.start_with?('/')

    re = '(/\w+)\s*(.*)'
    matches = message.text.match(re).to_a
    command = matches[1]
    rest = matches[2]
    tguser = message.from
    tgchat = message.chat
    p "C: #{command} from <#{tguser.id}> in chat <#{tgchat.id}> with rest <#{rest}>" if @verbose
    case command
    # add exam question (priviledged only)
    # /add n v text
    when '/add'
      add_question(bot, tguser, rest)

    # lokup all questions (priviledged only)
    when '/questions'
      all_questions(bot, tguser)

    # lokup all questions (priviledged only)
    when '/users'
      all_users(bot, tguser)

    # start exam (priviledged only)
    when '/startexam'
      start_exam(bot, tguser, rest)

    # stop exam, start peer review (priviledged only)
    when '/startreview'
      start_review(bot, tguser, rest)

    # sets all grades
    when '/setgrades'
      set_grades(bot, tguser, rest)

    # close and reload database: important before ctrl-break
    when '/reload'
      @dbl.close
      @dbl = DBLayer.new(@dbname, @verbose)

    when '/register'
      register_user(bot, tguser, rest)

    when '/answer'
      send_answer(bot, tguser, rest)

    when '/lookup'
      lookup_answer(bot, tguser, rest)

    when '/review'
      send_review(bot, tguser, rest)

    when '/help'
      helptext <<-HELP
        /register [name] -- register yourself as user (if name is skipped your telegram login will be taken)
        /answer n text -- send answer to nth question in your exam ticket
        /lookup [n] -- lookup your answer to nth question in the database. Without n returns all answers.
        /review user n grade text -- send review to nth question from user, set grade, send explanation
      HELP
      bot.api.send_message(chat_id: tguser.id, text: helptext)

    when '/exit'
      return true
    end
    return false
  end

  def shutdown
    @dbl.close
  end
end
