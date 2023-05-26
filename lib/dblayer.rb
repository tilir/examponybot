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
    return User.new(rs[0], rs[1], rs[2], rs[3])
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

  def collect_users(rs)
    users = []
    return users if rs.nil?

    rs.each do |row|
      pp row if @verbose
      next if row[1].nil? or row[2].nil? or row[3].nil?

      users.append User.new(row[0], row[1], row[2], row[3])
    end
    users
  end

  def all_users
    rs = @db.execute('SELECT * FROM users')
    collect_users(rs)
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def all_nonpriv_users
    rs = @db.execute('SELECT * FROM users WHERE privlevel = 1')
    collect_users(rs)
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

      questions.append Question.new(row[0], row[1], row[2], row[3])
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
    return Question.new(rs[0], rs[1], rs[2], rs[3])
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

  def register_question(uid, qid)
    rs = @db.get_first_row('SELECT * FROM userquestions WHERE user = ? AND question = ?', [uid, qid])
    if (rs.nil?)
      @db.execute('INSERT INTO userquestions (exam, user, question) VALUES (?, ?, ?)', [0, uid, qid])
      p "question #{qid} linked with user #{uid}" if @verbose
    else
      p "question #{qid} link with user #{uid} already exists" if @verbose
    end
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def user_nth_question(uid, n)
    multiline = <<-SQL
      SELECT userquestions.id FROM userquestions
      INNER JOIN questions ON userquestions.question = questions.id
      WHERE userquestions.user = ? AND questions.number = ?
    SQL
    rs = @db.get_first_row("#{multiline}", [uid, n])
    return nil if rs.nil?

    rs[0]
  end

  def collect_answers(rs)
    answers = []
    return answers if rs.nil?

    rs.each do |row|
      next if row[1].nil? or row[2].nil?

      answers.append Answer.new(row[0], row[1], row[2])
    end
    answers
  end

  def user_all_answers(uid)
    multiline = <<-SQL
      SELECT DISTINCT answers.* FROM userquestions
      INNER JOIN answers ON userquestions.id = answers.uqid
      WHERE userquestions.user = ?
    SQL
    rs = @db.execute(multiline)
    return nil if rs.nil?

    collect_answers(rs)
  end

  def all_answered_users
    multiline = <<-SQL
      SELECT DISTINCT users.* FROM userquestions
      INNER JOIN users ON users.id = userquestions.user
      INNER JOIN answers ON userquestions.id = answers.uqid
    SQL
    rs = @db.execute(multiline)
    return nil if rs.nil?

    collect_users(rs)
  end

  def record_answer(uqid, t)
    rs = @db.get_first_row('SELECT * FROM answers WHERE uqid = ?', [uqid])
    if (rs.nil?)
      @db.execute('INSERT INTO answers (uqid, answer) VALUES (?, ?)', [uqid, t])
      p "answer #{t} recorded for #{uqid}" if @verbose
    else
      @db.execute('UPDATE answers SET answer = ? WHERE id = ?', [t, rs[0]])
    end
  end

  def uqid_to_answer(uqid)
    rs = @db.get_first_row('SELECT * FROM answers WHERE uqid = ?', [uqid])
    return nil if rs.nil?

    return Answer.new(rs[0], rs[1], rs[2])
  end

  def close
    @db.close if @db
  end
end
