#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Data base layer to abstract out SQLite details
#
#------------------------------------------------------------------------------

require 'sqlite3'
require_relative './dbstructure'

class DBLayer
  def initialize(dbname, verbose)
    @db = SQLite3::Database.new(dbname)
    @verbose = verbose
    create_db_structure(@db)
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def add_user(tguser, priv, name)
    @db.execute('INSERT INTO users (userid, username, privlevel) VALUES (?, ?, ?)', [tguser.id, name, priv])
    p "user #{name} added with priv level #{priv}" if @verbose
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def update_user(tguser, priv, name)
    @db.execute('UPDATE users SET username = ? WHERE userid = ?', [name, tguser.id])
    p "user #{name} updated with priv level #{priv}" if @verbose
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def get_user_by_id(id)
    rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [id])
    return nil if rs.nil? or rs.empty?

    p "got user info: #{rs[1]} #{rs[2]} #{rs[3]}" if @verbose
    return User.new(rs[1], rs[2], rs[3])
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def users_empty?
    rs = @db.execute('SELECT * FROM users')
    p "user table empty" if @verbose and rs.empty?
    rs.empty?
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def all_users
    users = []
    rs = @db.execute('SELECT * FROM users')
    rs.each do |row|
      pp row if @verbose
      next if row[1].nil? or row[2].nil? or row[3].nil?

      users.append User.new(row[1], row[2], row[3])
    end
    users
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def add_question(number, variant, question)
    rs = @db.get_first_row('SELECT * FROM questions WHERE number = ? AND variant = ?', [number, variant])    
    if (rs.nil?)
      @db.execute('INSERT INTO questions (number, variant, question) VALUES (?, ?, ?)', [number, variant, question])
      p "question #{number} #{variant} #{question} added" if @verbose
    else      
      @db.execute('UPDATE questions SET question = ? WHERE number = ? AND variant = ?', [number, variant, question])
      p "question #{number} #{variant} #{question} updated" if @verbose
    end
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def all_questions
    questions = []
    rs = @db.execute('SELECT * FROM questions')
    rs.each do |row|
      pp row if @verbose
      next if row[1].nil? or row[2].nil? or row[3].nil?

      questions.append Question.new(row[1], row[2], row[3])
    end
    questions
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def get_question(number, variant)
    rs = @db.get_first_row('SELECT * FROM questions WHERE number = ? AND variant = ?', [number, variant])
    return nil if rs.empty?

    p "got question info: #{rs[1]} #{rs[2]} #{rs[3]}" if @verbose
    return Question.new(rs[1], rs[2], rs[3])
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def n_questions
    rs = @db.get_first_row('SELECT MAX(number) FROM questions')
    rs[0]
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def n_variants
    rs = @db.get_first_row('SELECT MAX(variant) FROM questions')
    rs[0]
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def exams_empty?
    rs = @db.execute('SELECT * FROM exams')
    rs.empty?
  end

  def add_exam(name)
    if exams_empty?
      @db.execute('INSERT INTO exams (state, name) VALUES (?, ?)', [0, name])
      p "exam added" if @verbose
    else
      p "sorry only one exam supported" if @verbose
    end
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  # this can support multiple exams in the future
  def read_exam_state
    rs = @db.get_first_row('SELECT * FROM exams')
    rs[1]
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def set_exam_state(state)
    rs = @db.get_first_row('SELECT * FROM exams')    
    @db.execute('UPDATE exams SET state = ? WHERE id = ?', [state, rs[0]])
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def close
    @db.close if @db
  end
end
