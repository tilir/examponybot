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
