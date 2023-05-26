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

  def check_user(api, dbuser, tguser)
    if (dbuser.nil?)
      api.send_message(chat_id: tguser.id, text: "Please register to exam")
      return -1
    end
    return 0
  end

  def check_priv_user(api, dbuser, tguser)
    return -1 if (check_user(api, dbuser, tguser) == -1)

    if (dbuser.privlevel != 0)
      api.send_message(chat_id: tguser.id, text: "Not enough priviledges for the command")
      return -1
    end
    return 0
  end

  # Priviledged part

  def all_users(api, tguser)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    allu = @dbl.all_users
    api.send_message(chat_id: tguser.id, text: "--- all users ---")
    allu.each do |usr|
      api.send_message(chat_id: tguser.id, text: "#{usr.userid} #{usr.username} #{usr.privlevel}")
    end
    api.send_message(chat_id: tguser.id, text: "---")
  end

  def add_question(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    p "add_question: #{rest}" if @verbose
    re = /(\d+)\s+(\d+)\s+(.+)/m
    m = rest.match(re).to_a
    n = m[1]
    v = m[2]
    t = m[3]

    p "add_question: #{n} #{v} #{t}" if @verbose
    @dbl.add_question(n, v, t)
    api.send_message(chat_id: tguser.id, text: "question added or updated")
  end

  def all_questions(api, tguser)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    allq = @dbl.all_questions
    api.send_message(chat_id: tguser.id, text: "--- all questions ---")
    allq.each do |qst|
      api.send_message(chat_id: tguser.id, text: "#{qst.number} #{qst.variant} #{qst.text}")
    end
    api.send_message(chat_id: tguser.id, text: "---")

    nn = @dbl.n_questions
    nv = @dbl.n_variants
    if (nn * nv != allq.length)
      api.send_message(chat_id: tguser.id, text: "Warning: #{nn} * #{nv} != #{allq.length}")
    end
  end

  def add_exam(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    if @dbl.exams_empty?
      @dbl.add_exam("exam")
      api.send_message(chat_id: tguser.id, text: "Exam added")
    else
      api.send_message(chat_id: tguser.id, text: "Exam already exists, currently only one exam possible")
    end
  end

  def start_exam(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    st = @dbl.read_exam_state
    if (st != EXAM_STATE[:stopped])
      api.send_message(chat_id: tguser.id, text: "Exam currently not in stopped mode")
      return
    end
    @dbl.set_exam_state(EXAM_STATE[:answering])

    allu = @dbl.all_nonpriv_users
    nn = @dbl.n_questions
    nv = @dbl.n_variants
    prng = Random.new

    allu.each do |dbuser|
      (1..nn).each do |n|
        v = prng.rand(1..nv)
        q = @dbl.get_question(n, v)
        @dbl.register_question(dbuser.id, q.id)
        api.send_message(chat_id: dbuser.userid, text: "Question #{n}, variant #{v}: #{q.text}")
      end
    end
  end

  def stop_exam(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    @dbl.set_exam_state(EXAM_STATE[:stopped])
  end

  def send_reviewing_task(api, tguser, student, reviewer)
    answs = @dbl.user_all_answers(student.id)
    p "got #{answs.length} answers to review from #{student.userid}"

    answs.each do |ans|
      revid = @dbl.create_review_assignment(reviewer.id, ans.uqid)
      api.send_message(chat_id: reviewer.userid, text: ">>> Review assignment #{revid}")
      api.send_message(chat_id: reviewer.userid, text: ans.text)
    end
  end

  def start_review(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    st = @dbl.read_exam_state
    if (st != EXAM_STATE[:answering])
      api.send_message(chat_id: tguser.id, text: "Exam currently not in answering mode")
      return
    end
    @dbl.set_exam_state(EXAM_STATE[:reviewing])

    allu = @dbl.all_answered_users
    if allu.nil?
      api.send_message(chat_id: tguser.id, text: "No answered users yet")
      return
    end

    nn = @dbl.n_questions

    astud = allu
    arev1 = allu.rotate(1)
    arev2 = allu.rotate(2)
    arev3 = allu.rotate(3)

    astud.zip(arev1, arev2, arev3).each do |s, r1, r2, r3|
      p "#{s.userid} : #{r1.userid} #{r2.userid} #{r3.userid}" if @verbose
      send_reviewing_task(api, tguser, s, r1)
      send_reviewing_task(api, tguser, s, r2)
      # if we will decide to make 3 reviewers, for beta-testing 2 enough
      # send_reviewing_task(api, tguser, s, r3)
    end
  end

  def due_done(user)
    return nil if @dbl.nreviews(user.id) < 2

    true
  end

  def grade_answer(answ)
    0
  end

  def set_grades(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_priv_user(api, dbuser, tguser) == -1)

    st = @dbl.read_exam_state
    if (st != EXAM_STATE[:reviewing])
      api.send_message(chat_id: tguser.id, text: "Exam currently not in reviewing mode")
      return
    end
    @dbl.set_exam_state(EXAM_STATE[:grading])

    allu = @dbl.all_answered_users
    if allu.nil?
      api.send_message(chat_id: tguser.id, text: "No answered users yet")
      return
    end

    allu.each do |user|
      if due_done(user).nil?
        api.send_message(chat_id: user.userid, text: "You haven't done your reviewing due and you will not be graded")
        next
      end
      totalgrade = 0
      answs = @dbl.user_all_answers(user.id)
      answs.each do |answ|
        totalgrade += grade_answer(answ)
      end
    end
  end

  # Non-priviledged part

  def register_user(api, tguser, name)
    name = "#{tguser.username}" if name.nil? or name == ""
    name = "#{tguser.id}" if name.nil? or name == ""
    p "register_user: #{name}" if @verbose

    # first user added with pedagogical priviledges
    if @dbl.users_empty?
      @dbl.add_user(tguser, 0, name)
      api.send_message(chat_id: tguser.id, text: "Registered (priviledged) as #{name}")
      return
    end

    if (not @dbl.exams_empty? and @dbl.read_exam_state != EXAM_STATE[:stopped])
      api.send_message(chat_id: tguser.id, text: "Exam currently not in stopped mode")
      return
    end

    # subsequent users added with student privileges
    dbuser = @dbl.get_user_by_id(tguser.id)
    if (dbuser.nil?)
      @dbl.add_user(tguser, 1, name)
      api.send_message(chat_id: tguser.id, text: "Registered as #{name}")
    else
      @dbl.update_user(tguser, 1, name)
      api.send_message(chat_id: tguser.id, text: "Reg info updated to: #{name}")
    end
  end

  def send_answer(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(api, dbuser, tguser) == -1)

    st = @dbl.read_exam_state
    if (st != EXAM_STATE[:answering])
      api.send_message(chat_id: tguser.id, text: "Exam not accepting answers now")
      return
    end

    re = /(\d+)\s+(.+)/m
    m = rest.match(re).to_a
    n = m[1].to_i
    t = m[2]
    nn = @dbl.n_questions

    p "Answer from #{tguser.username} to #{n} is: #{t}" if @verbose

    if (n > nn) or (n < 1)
      api.send_message(chat_id: tguser.id, text: "Answer have incorrect number. Please see /help.")
      return
    end
    uqid = @dbl.user_nth_question(dbuser.id, n)
    @dbl.record_answer(uqid, t)
    api.send_message(chat_id: tguser.id, text: "Answer recorded to #{uqid}")
  end

  def lookup_answer(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(api, dbuser, tguser) == -1)

    re = /(\d+)/m
    m = rest.match(re).to_a
    n = m[1].to_i
    nn = @dbl.n_questions

    if (n > nn) or (n < 1)
      api.send_message(chat_id: tguser.id, text: "Answer have incorrect number #{rest}. Please see /help.")
      return
    end

    uqid = @dbl.user_nth_question(dbuser.id, n)

    if uqid.nil?
      api.send_message(chat_id: tguser.id, text: "You don't have this question yet.")
      return
    end

    answ = @dbl.uqid_to_answer(uqid)

    if (answ.nil?)
      api.send_message(chat_id: tguser.id, text: "You haven't answered yet.")
      return
    end

    api.send_message(chat_id: tguser.id, text: answ.text)
  end

  def send_review(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(api, dbuser, tguser) == -1)

    st = @dbl.read_exam_state
    if (st != EXAM_STATE[:reviewing])
      api.send_message(chat_id: tguser.id, text: "Exam not accepting reviews now")
      return
    end

    re = /(\d+)\s+(\d+)\s+(.+)/m
    m = rest.match(re).to_a
    urid = m[1].to_i
    g = m[2].to_i
    t = m[3]

    uqid = @dbl.urid_to_uqid(dbuser.id, urid)
    if uqid.nil?
      api.send_message(chat_id: tguser.id, text: "#{urid} is not your review assignment")
      return
    end

    @dbl.record_review(urid, g, t)
  end

  def lookup_review(api, tguser, rest)
    dbuser = @dbl.get_user_by_id(tguser.id)
    return if (check_user(api, dbuser, tguser) == -1)

    re = /(\d+)/m
    m = rest.match(re).to_a
    urid = m[1].to_i

    uqid = @dbl.urid_to_uqid(dbuser.id, urid)
    if uqid.nil?
      api.send_message(chat_id: tguser.id, text: "#{urid} is not your review assignment")
      return
    end
    review = @dbl.query_review(urid)
    api.send_message(chat_id: tguser.id, text: "#{urid} review info. Grade: #{review.grade}. Text: #{review.text}")
  end

  def print_help
    <<-HELP
    /register -- register yourself as a user.
    /answer n text -- send answer to nth question in your exam ticket. Text can be multi-line.
    /lookup_answer n -- lookup your answer to nth question in the database.
    /review r grade text -- send review assignment r, set grade, send explanation.
    /lookup_review r -- lookup your review assignment in r's review in the database.
    HELP
  end

  # returns true if we need to exit
  def process_message(api, message)
    p "process_message: #{message.text}" if @verbose
    return false if message.text.nil?
    return false if not message.text.start_with?('/')

    re = /(\/\w+)\s*(.*)/m
    matches = message.text.match(re).to_a
    command = matches[1]
    rest = matches[2]
    tguser = message.from
    tgchat = message.chat
    p "C: #{command} from <#{tguser.id}> in chat <#{tgchat.id}> with rest <#{rest}>" if @verbose
    case command
    # add exam question (priviledged only)
    # /add n v text
    when '/addquestion'
      add_question(api, tguser, rest)

    # lokup all questions (priviledged only)
    when '/questions'
      all_questions(api, tguser)

    # lokup all questions (priviledged only)
    when '/users'
      all_users(api, tguser)

    when '/addexam'
      add_exam(api, tguser, rest)

    # start exam (priviledged only)
    # after start, users can submit answers
    when '/startexam'
      start_exam(api, tguser, rest)

    # start peer review (priviledged only)
    # users can no longer submit answers and shall submit reviews
    when '/startreview'
      start_review(api, tguser, rest)

    # sets all grades
    # users can no longer submit reviews but can query review results and grades
    when '/setgrades'
      set_grades(api, tguser, rest)

    # finish exam (priviledged only)
    # exam non-existent, everything cleaned up
    when '/stopexam'
      stop_exam(api, tguser, rest)

    # close and reload database: important before ctrl-break
    when '/reload'
      dbuser = @dbl.get_user_by_id(tguser.id)
      if (check_priv_user(api, dbuser, tguser) != -1)
        @dbl.close
        @dbl = DBLayer.new(@dbname, @verbose)
      end

    # --- non-priviledged part

    when '/register'
      register_user(api, tguser, rest)

    when '/answer'
      send_answer(api, tguser, rest)

    when '/lookup_answer'
      lookup_answer(api, tguser, rest)

    when '/review'
      send_review(api, tguser, rest)

    when '/lookup_review'
      lookup_review(api, tguser, rest)

    when '/help'
      helptext = print_help
      api.send_message(chat_id: tguser.id, text: "#{helptext}")
    when '/exit'
      dbuser = @dbl.get_user_by_id(tguser.id)
      return true if (check_priv_user(api, dbuser, tguser) != -1)
    else
      helptext = print_help
      api.send_message(chat_id: tguser.id, text: "Unknown command")
      api.send_message(chat_id: tguser.id, text: "#{helptext}")
    end
    return false
  end

  def shutdown
    @dbl.close
  end
end
