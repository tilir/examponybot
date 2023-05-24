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

  def get_user_by_id(id)
    rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [id])
    return nil if rs.empty?

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

  def add_question(number, variant, question)
    @db.execute('INSERT OR REPLACE INTO questions (number, variant, question) VALUES (?, ?, ?)', [number, variant, question])
    p "question #{number} #{variant} #{question} added" if @verbose
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

  def close
    @db.close if @db
  end
end
