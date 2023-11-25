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

EXAM_STATE = {
  stopped: 0,
  answering: 1,
  reviewing: 2,
  grading: 3
}

USER_STATE = {
  priviledged: 0,
  regular: 1,
  nonexistent: 2
}

class DBLayerError < StandardError
end

def create_db_structure(db)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY,
      userid INTEGER,
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
      id INTEGER PRIMARY KEY,#{'      '}
      state INTEGER,
      name TEXT
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS userquestions (
      id INTEGER PRIMARY KEY,
      exam INTEGER,
      user INTEGER,
      question INTEGER
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS answers (
      id INTEGER PRIMARY KEY,
      uqid INTEGER,
      answer TEXT#{'      '}
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS userreviews (
      id INTEGER PRIMARY KEY,
      reviewer INTEGER,
      uqid INTEGER
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS reviews (
      id INTEGER PRIMARY KEY,
      revid INTEGER,
      grade INTEGER,
      review TEXT#{'      '}
    );
  SQL
end

class User
  attr_reader :id, :userid, :username, :privlevel

  def initialize(dbl, userid, privlevel = nil, username = nil)
    @dbl = dbl

    unless (username.nil? or privlevel.nil?)
      @id = dbl.add_user(userid, privlevel, username)
      @userid = userid
      @username = username
      @privlevel = privlevel
      return
    end

    user = dbl.get_user_by_id(userid)
    unless (user.nil?)
      @id = user[0]
      @userid = user[1]
      @username = user[2]
      @privlevel = user[3]
      return
    end

    @privlevel = USER_STATE[:nonexistent]
  end

  def nth_question(examid, n)
    @dbl.user_nth_question(examid, @userid, n)
  end

  def n_reviews
    @dbl.nreviews(@userid)
  end

  def all_answers
    @dbl.user_all_answers(@id)
  end

  def to_userquestion(revid)
    @dbl.urid_to_uqid(@userid, revid)
  end

  def is_priviledged
    @privlevel == 0
  end

  private def to_s
    <<-USER
      User: #{@id}
      \tUserId: #{@userid}
      \tUserName: #{@username}
      \tPrivLevel: #{@privlevel}
    USER
  end
end

class Question
  attr_reader :id, :number, :variant, :text

  def initialize(dbl, number, variant, text = nil)
    @dbl = dbl

    unless (text.nil?)
      @id = dbl.add_question(number, variant, text)
      @number = number
      @variant = variant
      @text = text
      return
    end

    question = dbl.get_question(number, variant)
    unless (question.nil?)
      @id = question[0]
      @number = question[1]
      @variant = question[2]
      @text = question[3]
      return
    end

    raise DBLayerError, 'tried to get unregistered question'
  end

  private def to_s
    <<-QUESTION
      Question: #{@id}
      \tNumber: #{@number}
      \tVariant: #{@variant}
      \ttext: #{@text}
    QUESTION
  end
end

class Exam
  attr_reader :id, :name, :state

  def initialize(dbl, name)
    exam = dbl.add_exam(name)
    @dbl = dbl
    @id = exam[0]
    @state = exam[1]
    @name = exam[2]
  end

  def set_state(state)
    @dbl.set_exam_state(@name, state)
    @state = state
  end

  private def to_s
    <<-EXAM
      Exam: #{@id}
      \tName: #{@name}
      \tState: #{@state}
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

    Question.new(@dbl, question[1], question[2])
  end

  private def to_s
    <<-USERQUESTION
      User question: #{@id}
      \tExamId: #{@examid}
      \tUserId: #{@userid}
      \tQuestionId: #{questionid}
    USERQUESTION
  end
end

class Answer
  attr_reader :id, :uqid, :text

  def initialize(dbl, uqid, text = nil)
    @dbl = dbl
    
    unless (text.nil?)
      @id = dbl.record_answer(uqid, text)
      @uqid = uqid
      @text = text
      return
    end

    answer = dbl.uqid_to_answer(uqid)
    unless (answer.nil?)
      @id = answer[0]
      @uqid = answer[1]
      @text = answer[2]
      return
    end

    raise DBLayerError, 'tried to get unregistered answer'
  end

  def to_question
    userquestion = @dbl.awid_to_userquestion(@id)
    userquestion.to_question
  end

  def all_reviews
    @dbl.allreviews(@uqid)
  end

  private def to_s
    <<-ANSWER
      Answer: #{@id}
      \tUserQuestionId: #{@uqid}
      \tText: #{@text}
    ANSWER
  end
end

class UserReview
  attr_reader :id, :userid, :userquestionid

  def initialize(dbl, userid, userquestionid)
    @dbl = dbl
    @id = dbl.create_review_assignment(userid, userquestionid)
    @userid = userid
    @userquestionid = userquestionid
  end

  private def to_s
    <<-USERREVIEW
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

    unless (grade.nil? or text.nil?)
      @id = dbl.record_review(revid, grade, text)
      @revid = revid
      @grade = grade
      @text = text
      return
    end

    review = dbl.query_review(revid)
    unless (review.nil?)
      @id = review[0]
      @revid = review[1]
      @grade = review[2]
      @text = review[3]
      return
    end
    
    raise DBLayerError, 'unregistered review'
  end

  private def to_s
    <<-REVIEW
      User review: #{@id}
      \tReviewId: #{@revid}
      \tGrade: #{@grade}
      \tText: #{text}
    REVIEW
  end
end
