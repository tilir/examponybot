#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Data base high-level utility classes
#
#------------------------------------------------------------------------------

class DBLayerError < StandardError
end

module Schema
  def create_schema(db)    
    db.execute_batch <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY,
      userid INTEGER UNIQUE,
      username TEXT,
      privlevel INTEGER
    );

    CREATE TABLE IF NOT EXISTS questions (
      id INTEGER PRIMARY KEY,
      number INTEGER,
      variant INTEGER,
      question TEXT,
      UNIQUE(number, variant) ON CONFLICT REPLACE
    );

    CREATE TABLE IF NOT EXISTS exams (
      id INTEGER PRIMARY KEY,
      state INTEGER,
      name TEXT
    );

    CREATE TABLE IF NOT EXISTS userquestions (
      id INTEGER PRIMARY KEY,
      exam INTEGER REFERENCES exams(id) ON DELETE CASCADE,
      user INTEGER REFERENCES users(id) ON DELETE CASCADE,
      question INTEGER REFERENCES questions(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS answers (
      id INTEGER PRIMARY KEY,
      uqid INTEGER REFERENCES userquestions(id) ON DELETE CASCADE,
      answer TEXT
    );

    CREATE TABLE IF NOT EXISTS userreviews (
      id INTEGER PRIMARY KEY,
      reviewer INTEGER REFERENCES users(id) ON DELETE CASCADE,
      uqid INTEGER REFERENCES userquestions(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS reviews (
      id INTEGER PRIMARY KEY,
      revid INTEGER REFERENCES userreviews(id) ON DELETE CASCADE,
      grade INTEGER,
      review TEXT
    );
    SQL
  end
end

class DBUser
  attr_reader :id, :userid, :username, :privlevel

  def initialize(id, userid, username, privlevel)
    @id = id
    @userid = userid
    @username = username
    @privlevel = privlevel
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

class DBQuestion
  attr_reader :id, :number, :variant, :question

  def initialize(id, number, variant, question)
    @id = id
    @number = number
    @variant = variant
    @question = question
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

class DBExam
  attr_reader :id, :state, :name

  def initialize(id, state, name)
    @id = id
    @state = state
    @name = name
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2])
  end
end

class DBUserQuestion
  attr_reader :id, :exam_id, :user_id, :question_id

  def initialize(id, exam_id, user_id, question_id)
    @id = id
    @exam_id = exam_id
    @user_id = user_id
    @question_id = question_id
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

class DBAnswer
  attr_reader :id, :user_question_id, :answer

  def initialize(id, user_question_id, answer)
    @id = id
    @user_question_id = user_question_id
    @answer = answer
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2])
  end
end

class DBUserReview
  attr_reader :id, :reviewer_id, :user_question_id

  def initialize(id, reviewer_id, user_question_id)
    @id = id
    @reviewer_id = reviewer_id
    @user_question_id = user_question_id
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2])
  end
end

class DBReview
  attr_reader :id, :user_review_id, :grade, :review

  def initialize(id, user_review_id, grade, review)
    @id = id
    @user_review_id = user_review_id
    @grade = grade
    @review = review
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

