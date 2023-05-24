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
      exam INTEGER,
      user INTEGER,
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
  attr_accessor :userid
  attr_accessor :username
  attr_accessor :privlevel
  def initialize(userid, username, privlevel)
    @userid = userid
    @username = username
    @privlevel = privlevel
  end
end

class Question
  attr_accessor :number
  attr_accessor :variant
  attr_accessor :text
  def initialize(number, variant, text)
    @number = number
    @variant = variant
    @text = text
  end
end

class Answer
  attr_accessor :uqid
  attr_accessor :text
  def initialize(uqid, text)
    @uqid = uqid
    @text = text
  end
end

class Review
  attr_accessor :revid
  attr_accessor :grade
  attr_accessor :text
  def initialize(revid, grade, text)
    @revid = revid
    @grade = grade
    @text = text
  end
end
