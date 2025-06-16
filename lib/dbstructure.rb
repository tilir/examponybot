#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Data base structure and utility classes
#
#------------------------------------------------------------------------------

require_relative 'examstate'
require_relative 'userstate'

class DBLayerError < StandardError
end

def create_db_structure(db)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY,
      userid INTEGER UNIQUE,
      username TEXT,
      privlevel INTEGER
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS questions (
      id INTEGER PRIMARY KEY,
      number INTEGER,
      variant INTEGER,
      question TEXT
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS exams (
      id INTEGER PRIMARY KEY,
      state INTEGER,
      name TEXT
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS userquestions (
      id INTEGER PRIMARY KEY,
      exam INTEGER REFERENCES exams(id) ON DELETE CASCADE,
      user INTEGER REFERENCES users(id) ON DELETE CASCADE,
      question INTEGER REFERENCES questions(id) ON DELETE CASCADE
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS answers (
      id INTEGER PRIMARY KEY,
      uqid INTEGER REFERENCES userquestions(id) ON DELETE CASCADE,
      answer TEXT
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS userreviews (
      id INTEGER PRIMARY KEY,
      reviewer INTEGER REFERENCES users(id) ON DELETE CASCADE,
      uqid INTEGER REFERENCES userquestions(id) ON DELETE CASCADE
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS reviews (
      id INTEGER PRIMARY KEY,
      revid INTEGER REFERENCES userreviews(id) ON DELETE CASCADE,
      grade INTEGER,
      review TEXT
    );
  SQL
end

class User
  attr_reader :id, :userid, :username, :privlevel

  # generate methods like user.privileged? etc...
  UserStates::STATES.keys.each do |state_name|
    define_method "#{state_name}?" do
      @privlevel == UserStates.to_i(state_name)
    end
  end

  def initialize(dbl, userid, privlevel = nil, username = nil)
    @dbl       = dbl
    @userid    = userid

    if username && privlevel
      create_user(username, privlevel)
    else
      load_or_mark_nonexistent
    end
  end

  def level
    UserStates.to_sym(@privlevel)
  end

  def nth_question(examid, n)
    eid, uid, qid = @dbl.user_nth_question(examid, id, n)
    UserQuestion.new @dbl, eid, uid, qid
  end

  def review_count
    @dbl.nreviews(@userid)
  end

  def all_answers
    @dbl.user_all_answers(id)
  end

  def to_userquestion(revid)
    @dbl.urid_to_uqid(@userid, revid)
  end

  def to_s
    <<~USER.chomp
      User: #{id || '(not in DB)'}
      \tUserId: #{@userid}
      \tUserName: #{@username || '(none)'}
      \tPriv:    #{@privlevel})
    USER
  end

  private

  def create_user(name, level)
    priv = UserStates.to_i(level.is_a?(Symbol) ? level : level.to_sym)
    @id        = @dbl.add_user(@userid, priv, name)
    @username  = name
    @privlevel = priv
    Logger.print "Created user: #{@id} #{@userid} #{@username} #{@privlevel}"
  end

  def load_or_mark_nonexistent
    Logger.print "Query for #{@userid}"
    record = @dbl.get_user_by_id(@userid)
    if record
      @id, @userid, @username, @privlevel = record
      unless UserStates.valid?(@privlevel)
        raise ArgumentError, "Invalid user state code: #{@privlevel.inspect}"
      end
      Logger.print "Loaded from base: #{@username} #{@privlevel}"
    else
      @privlevel = UserStates.to_i(:nonexistent)
      Logger.print "No user found"
    end
  end
end

class Question
  attr_reader :id, :number, :variant, :text

  def initialize(dbl, number, variant, text = nil)
    @dbl = dbl
    @number = number
    @variant = variant

    if text
      create_question(text)
    else
      load_question_or_fail
    end
  end

  def to_s
    <<~QUESTION.chomp
      Question: #{id || '(not in DB)'}
      \tNumber: #{@number}
      \tVariant: #{@variant}
      \tText: #{@text || '(none)'}
    QUESTION
  end

  private

  def create_question(text)
    @id = @dbl.add_question(@number, @variant, text)
    @text = text
  end

  def load_question_or_fail
    record = @dbl.get_question(@number, @variant)
    if record
      @id, @number, @variant, @text = record
    else
      raise DBLayerError, "Tried to get unregistered question (#{@number}, #{@variant})"
    end
  end
end

class Exam
  attr_reader :id, :name

  def initialize(dbl, name)
    exam = dbl.add_exam(name)
    @dbl = dbl
    @id = exam[0]
    @raw_state = exam[1]  # number
    @name = exam[2]
  end

  def state
    ExamStates.to_sym(@raw_state)
  end

  def set_state(state_sym)
    code = ExamStates.to_i(state_sym)
    @dbl.set_exam_state(@name, code)
    @raw_state = code
  end

  def to_s
    <<~EXAM
      Exam: #{@id}
      \tName: #{@name}
      \tState: #{state} (#{@raw_state})
    EXAM
  end
end

class UserQuestion
  attr_reader :id, :examid, :userid, :questionid

  def initialize(dbl, examid, userid, questionid)
    @dbl = dbl
    @id = dbl.register_question(examid, userid, questionid)
    @examid = examid
    @userid = userid
    @questionid = questionid
  end

  def to_answer
    answer = @dbl.uqid_to_answer(@id)
    return nil if answer.nil?

    Answer.new(@dbl, @id)
  end

  def to_question
    question = @dbl.uqid_to_question(@id)
    return nil if question.nil?

    # question is [id, number, variant, text], so we pass number, variant, text
    Question.new(@dbl, question[1], question[2], question[3])
  end

  def to_s
    <<~USERQUESTION.chomp
      User question: #{@id}
      \tExamId: #{@examid}
      \tUserId: #{@userid}
      \tQuestionId: #{@questionid}
    USERQUESTION
  end
end

class Answer
  attr_reader :id, :uqid, :text

  def initialize(dbl, uqid, text = nil)
    @dbl = dbl
    @uqid = uqid

    if text
      create_answer(text)
    else
      load_answer
    end
  end

  def to_question
    uqrecord = @dbl.awid_to_userquestion(@id)

    if uqrecord
      examid, uid, qid = uqrecord 
      userquestion = UserQuestion.new @dbl, examid, uid, qid      
    else
      raise DBLayerError, 'tried to get unregistered answer'
    end

    userquestion.to_question
  end

  def all_reviews
    @dbl.allreviews(@uqid)
  end

  def to_s
    <<~ANSWER.chomp
      Answer: #{@id}
      \tUserQuestionId: #{@uqid}
      \tText: #{@text}
    ANSWER
  end

  private

  def create_answer(text)
    @id = @dbl.record_answer(@uqid, text)
    @text = text
  end

  def load_answer
    answer = @dbl.uqid_to_answer(@uqid)
    if answer
      @id, @uqid, @text = answer
    else
      raise DBLayerError, 'tried to get unregistered answer'
    end
  end
end

class UserReview
  attr_reader :id, :userid, :userquestionid

  def initialize(dbl, userid, userquestionid)
    @dbl = dbl
    @userid = userid
    @userquestionid = userquestionid
    @id = dbl.create_review_assignment(userid, userquestionid)
  end

  def to_s
    <<~USERREVIEW
      User review: #{@id}
      \tUserId: #{@userid}
      \tUserQuestionId: #{@userquestionid}
    USERREVIEW
  end
end

class Review
  attr_reader :id, :revid, :grade, :text

  def initialize(dbl, revid, grade = nil, text = nil)
    @dbl = dbl
    @revid = revid

    if grade && text
      @grade = grade
      @text = text
      @id = dbl.record_review(revid, grade, text)
    else
      review = dbl.query_review(revid)
      raise DBLayerError, "unregistered review" unless review

      @id, @revid, @grade, @text = review
    end
  end

  def to_s
    <<~REVIEW
      User review: #{@id}
      \tReviewId: #{@revid}
      \tGrade: #{@grade}
      \tText: #{@text}
    REVIEW
  end
end
