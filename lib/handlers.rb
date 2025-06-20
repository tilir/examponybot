# frozen_string_literal: true

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

require 'tempfile'
require_relative 'dblayer'

N_REVIEWERS = 2

class Handler
  attr_accessor :dbl # test purposes only

  def initialize(dbname)
    @dbl = DBLayer.new(dbname)
    return unless block_given?

    yield self
    shutdown
  end

  class Command
    def initialize(api, tguser, dbl)
      @api = api
      @tguser = tguser
      @dbl = dbl
    end

    def try_call(meth, *args)
      if respond_to?(meth.to_sym)
        send(meth.to_sym, *args)
        meth == 'exit'
      else
        handle_unknown_command(meth)
        false
      end
    rescue StandardError => e
      handle_error(e)
      false
    end

    def register(name = '')
      name = determine_name(name)
      Logger.print "Registering user: #{name}"

      if @dbl.users.empty?
        create_privileged_user(@tguser.id, name)
        return
      end

      # we need to register priviledged users even if no exams
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to register')
        return
      end

      # TODO: rework this to accept multiple exams
      exam = Exam.new(@dbl, 'exam')

      if %i[reviewing grading].include?(exam.state)
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting registers now: it is reviewing or grading')
        return
      end

      user = register_user(@tguser.id, name)
      return if exam.state == :stopped

      assign_questions(user, exam)
    end

    def help
      @api.send_message(chat_id: @tguser.id, text: help_text)
    end

    private

    def determine_name(name)
      name.empty? ? (@tguser.username || @tguser.id.to_s) : name
    end

    def register_user(userid, name)
      existing_user = @dbl.users.get_user_by_id(userid)
      handle_existing_or_new_user(existing_user, userid, name)
    end

    def create_privileged_user(userid, name)
      User.new(@dbl, userid, :privileged, name).tap do
        log_registration(userid, name, 'privileged')
      end
    end

    def handle_existing_or_new_user(user, userid, name)
      if user
        update_existing_user(user, userid, name)
      else
        create_regular_user(userid, name)
      end
    end

    def update_existing_user(user, userid, name)
      if user.username == name
        log_already_registered(userid, name)
        nil
      else
        User.new(@dbl, userid, :regular, name).tap do
          log_name_change(userid, user.username, name)
        end
      end
    end

    def create_regular_user(userid, name)
      User.new(@dbl, userid, :regular, name).tap do
        log_registration(userid, name, 'regular')
      end
    end

    def log_registration(userid, name, type)
      @api.send_message(chat_id: @tguser.id,
                        text: "User #{userid} registered as #{type}: #{name}")
    end

    def log_name_change(userid, old_name, new_name)
      @api.send_message(chat_id: @tguser.id,
                        text: "User #{userid} name changed from #{old_name} to #{new_name}")
    end

    def log_already_registered(userid, name)
      @api.send_message(chat_id: @tguser.id,
                        text: "User #{userid} already registered as #{name}")
    end

    def assign_questions(user, exam)
      Logger.print "Assigning questions for user: #{user.username}"
      n_questions = @dbl.questions.n_questions
      n_variants = @dbl.questions.n_variants
      prng = Random.new

      (1..n_questions).each do |n|
        variant = prng.rand(1..n_variants)
        question = Question.new(@dbl, n, variant)
        UserQuestion.new(@dbl, exam.id, user.id, question.id)
        send_question(user, question)
      end
    end

    def send_question(user, question)
      @api.send_message(
        chat_id: user.userid,
        text: "Question #{question.number}, variant #{question.variant}: #{question.text}"
      )
    end

    def help_text
      <<~HELP
        Available commands:
        /register [name] - Register yourself as user
        /help - Show this help
      HELP
    end

    def handle_unknown_command(command)
      @api.send_message(
        chat_id: @tguser.id,
        text: <<~TXT
          Unknown command /#{command}
          ---
          #{help_text}
        TXT
      )
    end

    def handle_error(error)
      error_location = error.backtrace_locations&.first
      if error_location
        file = error_location.path
        line = error_location.lineno
      end

      error_message = <<~ERROR_MSG
        +++ CRASH REPORT +++
        Time: #{Time.now}
        Error: #{error.class} - #{error.message}
        Location: #{file}:#{line}

        FULL BACKTRACE:
        #{error.backtrace&.join("\n")}

        CONTEXT:
        User: #{@tguser.inspect}
        Method: #{__method__}
      ERROR_MSG

      Logger.print(error_message)

      @api.send_message(
        chat_id: @tguser.id,
        text: error_message
      )
    end
  end

  class PrivilegedCommand < Command
    # interface commands
    def users
      allu = @dbl.users.all
      @api.send_message(chat_id: @tguser.id, text: '--- all users ---')
      allu.each do |usr|
        @api.send_message(chat_id: @tguser.id, text: "#{usr.userid} #{usr.username} #{usr.privlevel}")
      end
      @api.send_message(chat_id: @tguser.id, text: '---')
    end

    def addquestion(rest = '')
      Logger.print "add_question: #{rest}"
      re = /(\d+)\s+(\d+)\s+(.+)/m
      m = rest.match(re).to_a
      n = m[1]
      v = m[2]
      t = m[3]

      Logger.print "add_question broken into: #{n} #{v} #{t}"
      Question.new(@dbl, n, v, t)
      @api.send_message(chat_id: @tguser.id, text: 'question added or updated')
    end

    def questions
      allq = @dbl.questions.all
      @api.send_message(chat_id: @tguser.id, text: '--- all questions ---')
      allq.each do |qst|
        @api.send_message(chat_id: @tguser.id, text: "#{qst.number} #{qst.variant} #{qst.question}")
      end
      @api.send_message(chat_id: @tguser.id, text: '---')

      nn = @dbl.questions.n_questions
      nv = @dbl.questions.n_variants
      return unless nn * nv != allq.length

      @api.send_message(chat_id: @tguser.id, text: "Warning: #{nn} * #{nv} != #{allq.length}")
    end

    def addexam(_rest = '')
      if @dbl.exams.empty?
        Exam.new(@dbl, 'exam')
        @api.send_message(chat_id: @tguser.id, text: 'Exam added')
      else
        @api.send_message(chat_id: @tguser.id, text: 'Exam already exists, currently only one exam possible')
      end
    end

    def startexam(_rest = '')
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to start')
        return
      end
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :stopped
        @api.send_message(chat_id: @tguser.id, text: 'Exam currently not in stopped mode')
        return
      end
      exam.set_state(:answering)
      @api.send_message(chat_id: @tguser.id, text: 'Exam started, sending questions')
      @dbl.users.all_nonpriv.each { |dbuser| assign_questions(dbuser, exam) }
    end

    def stopexam(_rest = '')
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to stop')
        return
      end
      exam = Exam.new(@dbl, 'exam')
      if exam.state == :stopped
        @api.send_message(chat_id: @tguser.id, text: 'Exam already stopped')
        return
      end
      exam.set_state(:stopped)
      @api.send_message(chat_id: @tguser.id, text: 'Exam stopped')
    end

    def startreview(_rest = '')
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to start review')
        return
      end
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :answering
        @api.send_message(chat_id: @tguser.id, text: 'Exam currently not in answering mode')
        return
      end
      exam.set_state(:reviewing)

      allu = @dbl.answers.all_answered_users
      if allu.nil?
        @api.send_message(chat_id: @tguser.id, text: 'No answered users yet')
        return
      end

      astud = allu
      arev1 = allu.rotate(1)
      arev2 = allu.rotate(2)
      arev3 = allu.rotate(3)

      astud.zip(arev1, arev2, arev3).each do |s, r1, r2, r3|
        Logger.print "#{s.userid} : #{r1.userid} #{r2.userid} #{r3.userid}"
        send_reviewing_task(@api, @tguser, s, r1)
        send_reviewing_task(@api, @tguser, s, r2)
        # if we will decide to make 3 reviewers, for beta-testing 2 enough
        send_reviewing_task(@api, @tguser, s, r3) if N_REVIEWERS == 3
      end
    end

    def setgrades(_rest = '')
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to set grades')
        return
      end
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :reviewing
        @api.send_message(chat_id: @tguser.id, text: 'Exam currently not in reviewing mode')
        return
      end
      exam.set_state(:grading)

      nn = @dbl.questions.n_questions

      qualified = qualify_users(@api, @tguser)
      qualified.each do |user|
        totalgrade = 0
        answs = user.all_answers
        answs.each do |answ|
          allrevs = answ.all_reviews
          qst = answ.to_question
          if allrevs.empty?
            @api.send_message(chat_id: user.userid, text: "Sorry, answer to question #{qst.number} had no reviews")
            next
          end
          txt = <<~TXT
            Reviews for your question #{qst.number}
            --- Question text ---
            #{qst.question}
          TXT
          @api.send_message(chat_id: user.userid, text: txt)
          allrevs.each do |rev|
            txt = <<~TXT
              --- Review text ---
              #{rev.review}
              -------------------
              Review grade: #{rev.grade}
            TXT
            @api.send_message(chat_id: user.userid, text: txt)
          end
          totalgrade += grade_answer(allrevs)
        end
        totalgrade = (totalgrade.to_f / nn).round
        @api.send_message(chat_id: user.userid, text: "Your approx grade is #{totalgrade}")
      end
    end

    def answerstat(_rest = '')
      stat = @dbl.answers.user_answer_stats

      apitext = stat.map do |student|
        <<~REPORT
          Student: @#{student[:username]} (#{student[:telegram_id]})
          Answers submitted: #{student[:total_answers]}
          Answered questions: #{student[:answered_questions].join(', ')}
          ---
        REPORT
      end.join("\n")

      @api.send_message(chat_id: @tguser.id, text: "ANSWERS:\n#{apitext}")
    end

    def answersof(rest = '')
      re = /(.+)/m
      tgid = rest.match(re).to_s
      unless tgid
        @api.send_message(chat_id: @tguser.id, text: 'Wrong command format: specify tgid')
        return
      end
      dbuser = @dbl.users.get_user_by_id(tgid)
      unless dbuser
        @api.send_message(chat_id: @tguser.id, text: "No such user: #{tgid}")
        return
      end
      user = User.from_db_user(@dbl, dbuser)
      apitext = user.all_answers.map do |dbansw|
        dbqst = @dbl.answers.uqid_to_question(dbansw.uqid)
        <<~REPORT
          Answer:
          ---
          #{dbqst.question}
          ---
          #{dbansw.answer}
        REPORT
      end.join("\n")

      @api.send_message(chat_id: @tguser.id, text: "ANSWERS:\n#{apitext}")
    end

    def reviewstat(_rest = '')
      stat = @dbl.reviews.user_review_stats
      apitext = stat.map do |student|
        <<~REPORT
          Student: @#{student[:username]} (#{student[:telegram_id]})
          Reviews submitted: #{student[:total_reviews]}
          Answers reviewed: #{student[:reviewed_answers].join(', ')}
          ---
        REPORT
      end.join("\n")

      @api.send_message(chat_id: @tguser.id, text: "REVIEWS:\n#{apitext}")
    end

    def reviewsof(rest = '')
      re = /(.+)/m
      tgid = rest.match(re).to_s
      unless tgid
        @api.send_message(chat_id: @tguser.id, text: 'Wrong command format: specify tgid')
        return
      end
      dbuser = @dbl.users.get_user_by_id(tgid)
      unless dbuser
        @api.send_message(chat_id: @tguser.id, text: "No such user: #{tgid}")
        return
      end
      apitext = @dbl.reviews.tguser_reviews(tgid).map do |dbreview|
        uqid = @dbl.reviews.urid_to_uqid(dbuser.id, dbreview.user_review_id)
        dbansw = @dbl.answers.uqid_to_answer(uqid)
        dbqst = @dbl.answers.uqid_to_question(uqid)
        next if dbansw.nil? || dbqst.nil?

        <<~REPORT
          Review:
          ---
          #{dbqst.question}
          ---
          #{dbansw.answer}
          ---
          Grade: #{dbreview.grade}
          Text: #{dbreview.review}
        REPORT
      end.join("\n")

      @api.send_message(chat_id: @tguser.id, text: "REVIEWS:\n#{apitext}")
    end

    def dumpdb(_rest = '')
      Tempfile.create('db_dump.txt') do |f|
        f.write(@dbl.dumpdb)
        f.rewind
        @api.send_document(
          chat_id: @tguser.id,
          document: Faraday::UploadIO.new(f.path, 'text/plain'),
          caption: "DB Dump #{Time.now}"
        )
      end
    end

    def reload
      dbname = @dbl.name
      @dbl.close
      @dbl = DBLayer.new(dbname)
    end

    def exit
      true
    end

    private

    # utils
    def qualify_users(api, tguser)
      allu = @dbl.answers.all_answered_users
      if allu.nil?
        api.send_message(chat_id: tguser.id, text: 'No answered users yet')
        return []
      end

      qualified = []
      allu.each do |dbuser|
        user = User.from_db_user(@dbl, dbuser)
        userrevs = user.review_count
        assignments = @dbl.reviews.get_review_assignments(dbuser.userid)
        userreq = assignments.size
        if userrevs < userreq
          txt = <<~TXT
            You haven't done your reviewing due.
            Done #{userrevs} of #{userreq}
            You will not be graded
          TXT
          api.send_message(chat_id: user.userid, text: txt)
          next
        end
        qualified.append(user)
      end
      qualified
    end

    def grade_answer(allrevs)
      grade = 0
      allrevs.each do |rev|
        grade += rev.grade
      end
      (grade.to_f / allrevs.length).round
    end

    def send_reviewing_task(api, _tguser, dbuser, reviewer)
      student = User.from_db_user(@dbl, dbuser)
      answs = student.all_answers
      Logger.print "got #{answs.length} answers to review from #{student.userid}"

      answs.each do |ans|
        review = UserReview.new(@dbl, reviewer.id, ans.uqid)
        qst = ans.to_question
        txt = <<~TXT
          Review assignment: #{review.id}
          --- Question ---
          #{qst.question}
          --- Answer ---
          #{ans.text}
        TXT
        api.send_message(chat_id: reviewer.userid, text: txt)
        api.send_message(chat_id: reviewer.userid,
                         text: "You was assigned review #{review.id}. Please review it thoroughly.")
        Logger.print "Assigned review #{review.id} to #{reviewer.userid}"
      end
    end

    def help_text
      <<~HELP
        /addquestion n v text
        /questions
        /users
        /addexam [name]
        /startexam [name]
        /startreview [name]
        /setgrades [name]
        /stopexam [name]
        /answersof tguser
        /answerstat
        /reviewsof tguser
        /reviewstat
        /reload
        /exit
      HELP
    end
  end

  class NonPrivilegedCommand < Command
    def answer(rest = '')
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to send answer')
        return
      end
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :answering
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting answers now')
        return
      end

      re = /(?<qid>\d+)\s+(?<answer>.+)/m
      match = rest.match(re)
      Logger.print "<#{rest}> -> <#{match}>"

      unless match && match[:qid] && match[:answer]
        @api.send_message(chat_id: @tguser.id, text: 'You need to specify question number and answer text')
        return
      end

      n = match[:qid].to_i
      t = match[:answer]

      return unless check_question_number(n)

      dbuser = @dbl.users.get_user_by_id(@tguser.id)
      user = User.from_db_user(@dbl, dbuser)
      uqst = user.nth_question(exam.id, n)

      if uqst.nil?
        @api.send_message(chat_id: @tguser.id, text: "You don't have this question yet.")
        return
      end

      answ = @dbl.answers.create_or_update(uqst.id, t)
      raise 'uqid changed in process' unless answ.user_question_id == uqst.id

      @api.send_message(chat_id: @tguser.id, text: "Answer recorded to #{uqst.id}")
    end

    def lookup_question(rest = '')
      re = /(\d+)/m
      m = rest.match(re).to_a
      n = m[1].to_i

      return unless check_question_number(n)

      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to lookup')
        return
      end

      exam = Exam.new(@dbl, 'exam')
      dbuser = User.new(@dbl, @tguser.id)
      uqst = dbuser.nth_question(exam.id, n)

      if uqst.nil?
        @api.send_message(chat_id: @tguser.id, text: "You don't have this question yet.")
        return
      end

      qst = uqst.to_question

      if qst.nil?
        @api.send_message(chat_id: @tguser.id, text: "You don't have this question yet.")
        return
      end

      @api.send_message(chat_id: @tguser.id, text: qst.question)
    end

    def lookup_answer(rest = '')
      re = /(\d+)/m
      m = rest.match(re).to_a
      n = m[1].to_i

      unless n
        @api.send_message(chat_id: @tguser.id, text: 'Wrong command format: specify n')
        return
      end

      return unless check_question_number n

      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to lookup')
        return
      end

      exam = Exam.new(@dbl, 'exam')

      if exam.state != :answering
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting answers now')
        return
      end

      dbuser = User.new(@dbl, @tguser.id)
      uqst = dbuser.nth_question(exam.id, n)

      if uqst.nil?
        @api.send_message(chat_id: @tguser.id, text: "You don't have this question yet.")
        return
      end

      answ = uqst.to_answer

      if answ.nil?
        @api.send_message(chat_id: @tguser.id, text: "You haven't answered yet.")
        return
      end

      @api.send_message(chat_id: @tguser.id, text: answ.text)
    end

    def review(rest = '')
      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to post review')
        return
      end

      exam = Exam.new(@dbl, 'exam')

      if exam.state != :reviewing
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting reviews now')
        return
      end

      re = /(?<urid>\d+)\s+(?<grade>-?\d+)\s+(?<review>.+)/m
      match = rest.match(re)

      Logger.print "<#{rest}> -> <#{match}>"

      unless match && match[:urid] && match[:grade] && match[:review]
        @api.send_message(chat_id: @tguser.id, text: 'You need to specify review number, grade and review text')
        return
      end

      urid = match[:urid].to_i
      g = match[:grade].to_i
      t = match[:review]

      if (g < 1) || (g > 10)
        @api.send_message(chat_id: @tguser.id, text: 'Grade shall be 1 .. 10')
        return
      end

      dbuser = User.new(@dbl, @tguser.id)
      uqid = dbuser.to_userquestion(urid)
      if uqid.nil?
        @api.send_message(chat_id: @tguser.id, text: "#{urid} is not your review assignment")
        return
      end

      Review.new(@dbl, urid, g, t)
      @api.send_message(chat_id: @tguser.id, text: "Review assignment #{urid} recorded/updated")

      assignments = @dbl.reviews.get_review_assignments(@tguser.id)
      userreq = assignments.size
      userrevs = dbuser.review_count
      @api.send_message(chat_id: @tguser.id, text: "You sent #{userrevs} out of #{userreq} required reviews")
    end

    def lookup_review(rest = '')
      re = /(\d+)/m
      m = rest.match(re).to_a
      urid = m[1].to_i

      if @dbl.exams.empty?
        @api.send_message(chat_id: @tguser.id, text: 'No exam to post review')
        return
      end

      exam = Exam.new(@dbl, 'exam')

      if exam.state != :reviewing
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting reviews now')
        return
      end

      dbuser = User.new(@dbl, @tguser.id)
      uqid = dbuser.to_userquestion(urid)
      if uqid.nil?
        @api.send_message(chat_id: @tguser.id, text: "#{urid} is not your review assignment")
        return
      end
      review = Review.new(@dbl, urid)
      if review.nil?
        @api.send_message(chat_id: @tguser.id, text: "#{urid} review not found")
        return
      end
      @api.send_message(chat_id: @tguser.id, text: "#{urid} review info. Grade: #{review.grade}. Text: #{review.text}")
    end

    private

    def check_question_number(n)
      nn = @dbl.questions.n_questions
      if (n > nn) || (n < 1)
        @api.send_message(chat_id: @tguser.id,
                          text: "Question have incorrect number #{n}. Allowed range: [1 .. #{nn}].")
        return false
      end
      true
    end

    def help_text
      <<~HELP
        /register [name] -- change your name.
        /answer n text -- send answer to nth question in your exam ticket. Text can be multi-line.
        /lookup_question n -- lookup your nth question.
        /lookup_answer n -- lookup your answer to nth question.
        /review r grade text -- send review assignment r, set grade (from 1 to 10), send explanation.
        /lookup_review r -- lookup your review assignment in r's review.
      HELP
    end
  end

  # returns true if we need to exit
  def process_message(api, message)
    Logger.print "process_message: #{message.text}"

    Logger.print 'nil message' if message.text.nil?
    return false if message.text.nil?

    Logger.print 'incorrect message' unless message.text.start_with?('/')
    return false unless message.text.start_with?('/')

    re = /(\w+)\s*(.*)/m
    matches = message.text.match(re).to_a
    command = matches[1]
    rest = matches[2]
    tguser = message.from
    tgchat = message.chat
    Logger.print "C: /#{command} from <#{tguser.id}> in chat <#{tgchat.id}> with rest <#{rest}>"
    cmnd = get_command(api, tguser)
    rest.empty? ? cmnd.try_call(command) : cmnd.try_call(command, rest)
  end

  def shutdown
    @dbl.close
  end

  private

  def get_command(api, tguser)
    dbuser = @dbl.users.get_user_by_id(tguser.id)

    # case when no user present
    return Command.new(api, tguser, @dbl) unless dbuser

    # regular case
    case UserStates.to_sym(dbuser.privlevel)
    when :nonexistent
      Command.new(api, tguser, @dbl)
    when :privileged
      PrivilegedCommand.new(api, tguser, @dbl)
    else
      NonPrivilegedCommand.new(api, tguser, @dbl)
    end
  end
end
