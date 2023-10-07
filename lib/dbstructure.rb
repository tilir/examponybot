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

  def initialize(dbl, userid, username = nil, privlevel = nil)
    if (not (user = dbl.get_user_by_id(userid.id)).nil?)
      @dbl = dbl
      @id = user[0]
      @userid = user[1]
      @username = user[2]
      @privlevel = user[3]
      return
    end
    if (username != nil and privlevel != nil)
      @dbl = dbl
      @id = dbl.add_user(userid, privlevel, username)
      @userid = userid
      @username = username
      @privlevel = privlevel
      return
    end  
    raise DBLayerError.new "tried to get unregistered user"
  end

  def nth_question(examid, n) = @dbl.user_nth_question(examid, @userid.id, n)
  def n_reviews = @dbl.nreviews @userid.id
  def update_name(name) = @dbl.update_user(@userid, @privlevel, name)
  def all_answers = @dbl.user_all_answers @id
  def to_userquestion(revid) = @dbl.urid_to_uqid(@userid.id, revid)
end

class Question
  attr_reader :id
  attr_reader :number
  attr_reader :variant
  attr_reader :text

  def initialize(dbl, number, variant, text = nil)
    if (not (question = dbl.get_question(number, variant)).nil?)
      @dbl = dbl
      @id = question[0]
      @number = question[1]
      @variant = question[2]
      @text = question[3]
      return 
    end
    if (text != nil)
      @dbl = dbl
      @id = dbl.add_question(number, variant, text)
      @number = number
      @variant = variant
      @text = text
      return
    end    
    raise DBLayerError.new "tried to get unregistered question"
  end
  def to_answer = @dbl.qid_to_answer @id
end

class Exam
  attr_reader :id
  attr_reader :name
  attr_reader :state

  def initialize(dbl, name)
    if (not (exam = dbl.get_exam(name)).nil?)
      @dbl = dbl
      @id = exam[0]
      @state = exam[1]
      @name = exam[2]
      return
    end
    @dbl = dbl
    @id = dbl.add_exam(name)
    @state = 0
    @name = name
  end

  def set_state(state) = @dbl.set_exam_state(@name, @state)
end

class UserQuestion 
  attr_reader :id
  attr_reader :examid
  attr_reader :userid
  attr_reader :questionid

  def initialize(dbl, examid, userid, questionid)
    @dbl = dbl
    @id = dbl.register_question(examid, userid, questionid)
    @examid = examid
    @userid = userid
    @questionid = questionid
  end
end

class Answer
  attr_reader :id
  attr_reader :qid
  attr_reader :text

  def initialize(dbl, qid, text = nil)
    if (not (answer = dbl.qid_to_answer(qid)).nil?)
      @dbl = dbl
      @id = answer[0]
      @uqid = answer[1]
      @text = answer[2]
      return
    end
    if (text != nil)
      @dbl = dbl
      @id = dbl.record_answer(qid, text)
      @qid = qid
      @text = text
      return
    end
  raise DBLayerError.new "unregistered answer"
  end

  def all_reviews = @dbl.allreviews @uqid
end

class UserReview 
  attr_reader :id
  attr_reader :userid
  attr_reader :userquestionid

  def initialize(dbl, userid, userquestionid)
    @dbl = dbl
    @id = dbl.create_review_assignment(userid, userquestionid)
    @userid = userid
    @userquestionid = userquestionid
  end
end

class Review
  attr_reader :id
  attr_reader :revid
  attr_reader :grade
  attr_reader :text
  def initialize(dbl, revid, grade = nil, text = nil)
    if (not (review = dbl.query_review revid).nil?)
      @dbl = dbl
      @id = review[0]
      @revid = review[1]
      @grade = review[2]
      @text = review[3]
      return
    end
    if (grade != nil and text != nil)
      @dbl = dbl
      @id = dbl.record_review(revid, grade, text)
      @revid = revid
      @grade = grade
      @text = text
      return
    end
    raise DBLayerError.new "unregistered review"
  end
end
