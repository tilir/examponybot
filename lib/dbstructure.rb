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
      id INTEGER PRIMARY KEY,      
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
      answer TEXT      
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
      review TEXT      
    );
  SQL
end

class User
  attr_reader :id
  attr_reader :userid
  attr_reader :username
  attr_reader :privlevel

  def initialize(db, userid, username = None, privlevel = None)
    if (not (user = db.get_user_by_id(userid)).nil?)
      @db = db
      @id = user[0]
      @userid = user[1]
      @username = user.username[2]
      return @privlevel = user.privlevel[3]
    end
    if (username != None and privlevel != None)
      @db = db
      @id = db.add_user(userid, privlevel, username)
      @userid = userid
      @username = username
      return @privlevel = privlevel
    end    
    raise DBLayerError.new "tried to get unregistered user"
  end

  def update_name(name) = @db.update_user(@userid, @privlevel, name)
  def all_answers = @db.user_all_answers @userid
end

class Question
  attr_reader :id
  attr_reader :number
  attr_reader :variant
  attr_reader :text

  def initialize(db, number, variant, text = None)
    if (not (question = db.get_question(number, variant)).nil?)
      @db = db
      @id = question[0]
      @number = question[1]
      @variant = question[2]
      return @text = question[3]
    end
    if (text != None)
      @db = db
      @id = db.add_question(number, variant, text)
      @number = number
      @variant = variant
      return @text = text
    end    
    raise DBLayerError.new "tried to get unregistered question"
  end
end

class Exam
  attr_reader :id
  attr_reader :name
  attr_reader :state

  def initialize(db, name)
    if (not (exam = db.get_exam(name)).nil?)
      @db = db
      @id = exam[0]
      @state = exam[1]
      return @name = exam[2]
    end
    @db = db
    @id = db.add_exam(name)
    @state = 0
    @name = name
  end

  def set_state(state) = @db.set_exam_state(@name, @state)
end

class UserQuestion 
  attr_reader :id
  attr_reader :examid
  attr_reader :userid
  attr_reader :questionid

  # f = true - register
  # f = false - nth
  def initialize(db, examid, userid, questionid, f)
    if (f)
      @db = db
      @id = db.register_question(examid, userid, questionid)
      @examid = examid
      @userid = userid
      @questionid = questionid
    else   
      userquestion = db.user_nth_question(examid, userid, questionid)
      @db = db
      @id = userquestion[0]
      @examid = userquestion[1]
      @userid = userquestion[2]
      @questionid = userquestion[3]
    end
    raise DBLayerError.new "unregistered userquestion"
  end

  def to_question
    question = @db.uqid_to_question @id
    Question.new(db, question[1], question[2], question[3])
  end
end

class Answer
  attr_reader :id
  attr_reader :uqid
  attr_reader :text

  def initialize(db, uqid, text = None)
    if (not (answer = db.uqid_to_answer(uqid)).nil?)
      @db = db
      @id = answer[0]
      @uqid = answer[1]
      return @text = answer[2]
    end
    if (text != None)
      @db = db
      @id = db.record_answer(uqid, text)
      @uqid = uqid
      return @text = text
    end
  raise DBLayerError.new "unregistered answer"
  end
end

class UserReview 
  attr_reader :id
  attr_reader :userid
  attr_reader :userquestionid

  def initialize(db, userid, userquestionid)
    @db = db
    @id = db.create_review_assignment(userid, userquestionid)
    @userid = userid
    @userquestionid = userquestionid
    raise DBLayerError.new "unregistered userreview"
  end

  def n_reviews = @db.nreviews @userid
  def all_reviews = @db.allreviews @userquestionid
end

class Review
  attr_reader :id
  attr_reader :revid
  attr_reader :grade
  attr_reader :text
  def initialize(db, revid, grade = None, text = None)
    if (not (review = db.query_review revid).nil?)
      @db = db
      @id = review[0]
      @revid = review[1]
      @grade = review[2]
      return @text = review[3]
    end
    if (grade != None and text != None)
      @db = db
      @id = db.record_review(revid, grade, text)
      @revid = revid
      @grade = grade
      return @text = text
    end
    raise DBLayerError.new "unregistered review"
  end
end
