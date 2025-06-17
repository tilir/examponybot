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

N_REVIEWERS = 3

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
      res = nil
      if respond_to?(meth.to_sym)
        res = send(meth.to_sym, *args)
      else
        helptext = print_help
        txt = <<~TXT
          Unknown command /#{meth}
          ---
          #{helptext}
        TXT
        @api.send_message(chat_id: @tguser.id, text: txt)
      end
      res && meth == 'exit' ? true : false
    end

    def register(name = '')
      name = "#{@tguser.username}" if name.nil? or name == ''
      name = "#{@tguser.id}" if name.nil? or name == ''
      Logger.print "register_user: #{name}"

      # first user added with pedagogical priviledges
      if @dbl.users.empty?
        User.new(@dbl, @tguser.id, :privileged, name)
        @api.send_message(chat_id: @tguser.id, text: "Registered (privileged) as #{name}")
        return
      end

      allu = @dbl.all_nonpriv_users
      found = allu.find{ |usr| usr.userid == @tguser.id }

      # subsequent users added with student privileges
      dbuser = User.new(@dbl, @tguser.id, :regular, name)
      @api.send_message(chat_id: @tguser.id, text: "Registered/updated as #{name}")
 
      # new reg with running exam getting its questions
      if !@dbl.exams.empty?
        exam = Exam.new(@dbl, 'exam')
        if found.nil? and exam.state != :stopped
          nn = @dbl.n_questions
          nv = @dbl.n_variants
          prng = Random.new

          (1..nn).each do |n|
            v = prng.rand(1..nv)
            q = Question.new(@dbl, n, v)
            UserQuestion.new(@dbl, exam.id, dbuser.id, q.id)
            @api.send_message(chat_id: dbuser.userid, text: "Question #{n}, variant #{v}: #{q.text}")
          end
        end
      end
    end

    def help
      helptext = print_help
      @api.send_message(chat_id: @tguser.id, text: helptext)
    end

    private def print_help
      <<~HELP
        /register [name] -- register yourself as a user.
      HELP
    end
  end

  class PrivilegedCommand < Command
    # utils
    private def qualify_users(api, tguser, userreq)
      allu = @dbl.all_answered_users
      if allu.nil?
        api.send_message(chat_id: tguser.id, text: 'No answered users yet')
        return []
      end

      qualified = []
      allu.each do |user|
        userrevs = user.n_reviews
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

    private def grade_answer(allrevs)
      grade = 0
      allrevs.each do |rev|
        grade += rev.grade
      end
      (grade.to_f / allrevs.length).round
    end

    private def send_reviewing_task(api, _tguser, student, reviewer)
      answs = student.all_answers
      p "got #{answs.length} answers to review from #{student.userid}"

      answs.each do |ans|
        review = UserReview.new(@dbl, reviewer.id, ans.uqid)
        qst = ans.to_question
        txt = <<~TXT
          Review assignment: #{review.id}
          --- Question ---
          #{qst.text}
          --- Answer ---
          #{ans.text}
        TXT
        api.send_message(chat_id: reviewer.userid, text: txt)
      end
    end

    # iterface
    def users
      allu = @dbl.all_users
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
      allq = @dbl.all_questions
      @api.send_message(chat_id: @tguser.id, text: '--- all questions ---')
      allq.each do |qst|
        @api.send_message(chat_id: @tguser.id, text: "#{qst.number} #{qst.variant} #{qst.text}")
      end
      @api.send_message(chat_id: @tguser.id, text: '---')

      nn = @dbl.n_questions
      nv = @dbl.n_variants
      return unless nn * nv != allq.length

      @api.send_message(chat_id: @tguser.id, text: "Warning: #{nn} * #{nv} != #{allq.length}")
    end

    def addexam(rest = '')
      if @dbl.exams.empty?
        Exam.new(@dbl, 'exam')
        @api.send_message(chat_id: @tguser.id, text: 'Exam added')
      else
        @api.send_message(chat_id: @tguser.id, text: 'Exam already exists, currently only one exam possible')
      end
    end

    def startexam(rest = '')
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :stopped
        @api.send_message(chat_id: @tguser.id, text: 'Exam currently not in stopped mode')
        return
      end
      exam.set_state(:answering)

      allu = @dbl.all_nonpriv_users
      nn = @dbl.n_questions
      nv = @dbl.n_variants
      prng = Random.new

      allu.each do |dbuser|
        (1..nn).each do |n|
          v = prng.rand(1..nv)
          q = Question.new(@dbl, n, v)
          UserQuestion.new(@dbl, exam.id, dbuser.id, q.id)
          @api.send_message(chat_id: dbuser.userid, text: "Question #{n}, variant #{v}: #{q.text}")
        end
      end
    end

    def stopexam(rest = '')
      Exam.new(@dbl, 'exam').set_state(:stopped)
    end

    def startreview(rest = '')
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :answering
        @api.send_message(chat_id: @tguser.id, text: 'Exam currently not in answering mode')
        return
      end
      exam.set_state(:reviewing)

      allu = @dbl.all_answered_users
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

    def setgrades(rest = '')
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :reviewing
        @api.send_message(chat_id: @tguser.id, text: 'Exam currently not in reviewing mode')
        return
      end
      exam.set_state(:grading)

      nn = @dbl.n_questions
      nv = @dbl.n_variants
      userreq = nv * N_REVIEWERS

      qualified = qualify_users(@api, @tguser, userreq)
      qualified.each do |user|
        totalgrade = 0
        answs = user.all_answers
        answs.each do |answ|
          allrevs = answ.allreviews
          qst = answ.to_question
          if allrevs.empty?
            @api.send_message(chat_id: user.userid, text: "Sorry, answer to question #{qst.number} had no reviews")
            next
          end
          txt = <<~TXT
            Reviews for your question #{qst.number}
            --- Question text ---
            #{qst.text}
          TXT
          @api.send_message(chat_id: user.userid, text: txt)
          allrevs.each do |rev|
            txt = <<~TXT
              --- Review text ---
              #{rev.text}
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

    def reload
      dbname = @dbl.name
      @dbl.close
      @dbl = DBLayer.new(dbname)
    end

    def exit
      true
    end

    private def print_help
      <<~HELP
        /addquestion n v text
        /questions
        /users
        /addexam [name]
        /startexam [name]
        /startreview [name]
        /setgrades [name]
        /stopexam [name]
        /reload
        /exit
      HELP
    end
  end

  class NonPrivilegedCommand < Command
    private def check_question_number(n)
      nn = @dbl.n_questions
      if (n > nn) or (n < 1)
        @api.send_message(chat_id: @tguser.id,
                          text: "Question have incorrect number #{n}. Allowed range: [1 .. #{nn}].")
        return false
      end
      true
    end

    def answer(rest = '')
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :answering
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting answers now')
        return
      end

      re = /(\d+)\s+(.+)/m
      m = rest.match(re).to_a
      n = m[1].to_i
      t = m[2]

      Logger.print "Answer from #{@tguser.username} to #{n} is: #{t}"

      return unless check_question_number(n)

      dbuser = User.new(@dbl, @tguser.id)
      uqst = dbuser.nth_question(exam.id, n)

      if uqst.nil?
        @api.send_message(chat_id: @tguser.id, text: "You don't have this question yet.")
        return
      end
      
      Answer.new(@dbl, uqst.id, t)
      @api.send_message(chat_id: @tguser.id, text: "Answer recorded to #{uqst.id}")
    end

    def lookup_question(rest = '')
      re = /(\d+)/m
      m = rest.match(re).to_a
      n = m[1].to_i

      return unless check_question_number(n)

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

      @api.send_message(chat_id: @tguser.id, text: qst.text)
    end

    def lookup_answer(rest = '')
      re = /(\d+)/m
      m = rest.match(re).to_a
      n = m[1].to_i

      return unless check_question_number n

      exam = Exam.new(@dbl, 'exam')
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
      exam = Exam.new(@dbl, 'exam')
      if exam.state != :reviewing
        @api.send_message(chat_id: @tguser.id, text: 'Exam not accepting reviews now')
        return
      end

      re = /(\d+)\s+(\d+)\s+(.+)/m
      m = rest.match(re).to_a
      urid = m[1].to_i
      g = m[2].to_i
      t = m[3]

      if g < 1 or g > 10
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

      nv = @dbl.n_variants
      userreq = nv * N_REVIEWERS
      userrevs = dbuser.n_reviews
      @api.send_message(chat_id: @tguser.id, text: "You sent #{userrevs} out of #{userreq} required reviews")
    end

    def lookup_review(rest = '')
      re = /(\d+)/m
      m = rest.match(re).to_a
      urid = m[1].to_i

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

    private def print_help
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

  private def get_command(api, tguser)
    dbuser = User.new(@dbl, tguser.id)
    return Command.new(api, tguser, @dbl) if dbuser.level == :nonexistent
    return PrivilegedCommand.new(api, tguser, @dbl) if dbuser.level == :privileged

    NonPrivilegedCommand.new(api, tguser, @dbl)
  end

  # returns true if we need to exit
  def process_message(api, message)
    Logger.print "process_message: #{message.text}"

    Logger.print "nil message" if message.text.nil?
    return false if message.text.nil?

    Logger.print "incorrect message" unless message.text.start_with?('/')
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
end
