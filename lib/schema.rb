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
  def create_schema(db_layer)
    db = db_layer.instance_variable_get(:@db)
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
      question TEXT
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
