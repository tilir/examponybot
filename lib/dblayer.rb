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
require_relative 'dbstructure'

class Logger
  def self.set_verbose(verbose)
    @@verbose = verbose
  end

  def self.print(message)
    @@verbose ||= false
    p message if @@verbose
  end
end

class DBLayer
  attr_reader :name

  def initialize(dbname)
    @db = SQLite3::Database.new(dbname)
    @name = dbname
    create_db_structure(@db)
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def add_user(tguser, priv, name)
    rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [tguser])
    if rs.nil?
      @db.execute('INSERT INTO users (userid, username, privlevel) VALUES (?, ?, ?)', [tguser, name, priv])
      Logger.print "user #{name} added with priv level #{priv}"
    else 
      @db.execute('UPDATE users SET username = ? WHERE userid = ?', [name, tguser])
      Logger.print "user #{name} updated with priv level #{priv}"
    end
    rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [tguser])
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def get_user_by_id(userid)
    rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [userid])
    return nil if rs.nil? or rs.empty?
    return rs    
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def users_empty?
    rs = @db.execute('SELECT * FROM users')
    Logger.print 'user table empty' if rs.empty?
    rs.empty?
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  private def collect_users(rs)
    users = []
    return users if rs.nil?

    rs.each do |row|
      Logger.print row
      next if row[1].nil? or row[2].nil? or row[3].nil?

      users.append User.new(self, row[1])
    end
    users
  end

  def all_users
    rs = @db.execute('SELECT * FROM users')
    collect_users(rs)
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def all_nonpriv_users
    rs = @db.execute('SELECT * FROM users WHERE privlevel = 1')
    collect_users(rs)
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def add_question(number, variant, question)
    rs = @db.get_first_row('SELECT * FROM questions WHERE number = ? AND variant = ?', [number, variant])
    if rs.nil?
      @db.execute('INSERT INTO questions (number, variant, question) VALUES (?, ?, ?)', [number, variant, question])
      Logger.print "question #{number} #{variant} #{question} added"
    else
      @db.execute('UPDATE questions SET question = ? WHERE number = ? AND variant = ?', [question, number, variant])
      Logger.print "question #{number} #{variant} #{question} updated"
    end
    rs = @db.get_first_row('SELECT * FROM questions WHERE number = ? AND variant = ?', [number, variant])
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def all_questions
    questions = []
    rs = @db.execute('SELECT * FROM questions')
    rs.each do |row|
      Logger.print row
      next if row[1].nil? or row[2].nil? or row[3].nil?

      questions.append Question.new(self, row[1], row[2])
    end
    questions
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def get_question(number, variant)
    rs = @db.get_first_row('SELECT * FROM questions WHERE number = ? AND variant = ?', [number, variant])
    return nil if rs.nil?

    Logger.print "got question info: #{rs[1]} #{rs[2]} #{rs[3]}"
    [rs[0], rs[1], rs[2], rs[3]]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def n_questions
    rs = @db.get_first_row('SELECT MAX(number) FROM questions')
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def n_variants
    rs = @db.get_first_row('SELECT MAX(variant) FROM questions')
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def exams_empty?
    rs = @db.execute('SELECT * FROM exams')
    rs.empty?
  end

  def add_exam(name)
    rs = @db.get_first_row('SELECT * FROM exams WHERE name = ?', [name])
    if rs.nil?
      if exams_empty?
        @db.execute('INSERT INTO exams (state, name) VALUES (?, ?)', [0, name])
        Logger.print 'exam added'
        rs = @db.get_first_row('SELECT * FROM exams WHERE name = ?', [name])
      else
        Logger.print 'sorry only one exam supported'
      end
    else
      Logger.print "exam #{name} already exists"
    end
    [rs[0], rs[1], rs[2]]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def set_exam_state(name, state)
    rs = @db.get_first_row('SELECT * FROM exams WHERE name = ?', [name])
    @db.execute('UPDATE exams SET state = ? WHERE id = ?', [state, rs[0]])
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def register_question(eid, uid, qid)
    rs = @db.get_first_row('SELECT * FROM userquestions WHERE exam = ? AND user = ? AND question = ?', [eid, uid, qid])
    if rs.nil?
      @db.execute('INSERT INTO userquestions (exam, user, question) VALUES (?, ?, ?)', [eid, uid, qid])
      Logger.print "question #{qid} linked with user #{uid}"
      rs = @db.get_first_row('SELECT * FROM userquestions WHERE exam = ? AND user = ? AND question = ?',
                             [eid, uid, qid])
    else
      Logger.print "question #{qid} link with user #{uid} already exists"
    end
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def user_nth_question(eid, uid, n)
    multiline = <<-SQL
      SELECT * FROM userquestions
      INNER JOIN questions ON userquestions.question = questions.id
      WHERE userquestions.exam = ? AND userquestions.user = ? AND questions.number = ?
    SQL
    rs = @db.get_first_row("#{multiline}", [eid, uid, n])
    return nil if rs.nil?

    UserQuestion.new(self, rs[1], rs[2], rs[3])
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  private def collect_answers(rs)
    answers = []
    return answers if rs.nil?

    rs.each do |row|
      Logger.print row
      next if row[1].nil? or row[2].nil?

      answers.append(Answer.new(self, row[1]))
    end
    answers
  end

  def user_all_answers(uid)
    multiline = <<-SQL
      SELECT DISTINCT answers.* FROM userquestions
      INNER JOIN answers ON userquestions.id = answers.uqid
      WHERE userquestions.user = ?
    SQL
    rs = @db.execute(multiline, [uid])
    collect_answers(rs)
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
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
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def record_answer(uqid, t)
    rs = @db.get_first_row('SELECT * FROM answers WHERE uqid = ?', [uqid])
    if rs.nil?
      @db.execute('INSERT INTO answers (uqid, answer) VALUES (?, ?)', [uqid, t])
      Logger.print "answer #{t} recorded for #{uqid}"
      rs = @db.get_first_row('SELECT * FROM answers WHERE uqid = ?', [uqid])
    else
      @db.execute('UPDATE answers SET answer = ? WHERE id = ?', [t, rs[0]])
      Logger.print "answer #{t} updated for #{uqid}"
    end
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def uqid_to_answer(uqid)
    multiline = <<-SQL
      SELECT * FROM answers
      INNER JOIN userquestions ON userquestions.id = answers.uqid
      WHERE userquestions.id = ?
    SQL
    rs = @db.get_first_row(multiline, [uqid])
    return nil if rs.nil?

    [rs[0], rs[1], rs[2]]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def awid_to_userquestion(awid)
    multiline = <<-SQL
      SELECT * FROM userquestions
      INNER JOIN answers ON userquestions.id = answers.uqid
      WHERE answers.id = ?
    SQL
    rs = @db.get_first_row(multiline, [awid])
    return nil if rs.nil?

    UserQuestion.new(self, rs[1], rs[2], rs[3])
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def uqid_to_question(uqid)
    multiline = <<-SQL
      SELECT DISTINCT * FROM questions
      INNER JOIN userquestions ON questions.id = userquestions.question
      WHERE userquestions.id = ?#{'      '}
    SQL
    rs = @db.get_first_row(multiline, [uqid])
    return nil if rs.nil?

    [rs[0], rs[1], rs[2], rs[3]]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def nreviews(rid)
    multiline = <<-SQL
      SELECT COUNT(reviews.id) FROM reviews
      INNER JOIN userreviews ON reviews.revid = userreviews.id
      WHERE userreviews.reviewer = ?;
    SQL
    rs = @db.get_first_row(multiline, [rid])
    Logger.print "found #{rs[0]} reviews from #{rid}"
    rs[0]
  end

  def create_review_assignment(rid, uqid)
    rs = @db.get_first_row('SELECT * FROM userreviews WHERE reviewer = ? AND uqid = ?', [rid, uqid])
    if rs.nil?
      @db.execute('INSERT INTO userreviews (reviewer, uqid) VALUES (?, ?)', [rid, uqid])
      Logger.print "uqid #{uqid} linked with reviewer #{rid}"
      rs = @db.get_first_row('SELECT * FROM userreviews WHERE reviewer = ? AND uqid = ?', [rid, uqid])
    else
      Logger.print "uqid #{uqid} link with reviewer #{rid} already exists"
    end
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  # userreview.userquestionid
  def urid_to_uqid(uid, rid)
    rs = @db.get_first_row('SELECT uqid FROM userreviews WHERE reviewer = ? AND id = ?', [uid, rid])
    return rs if rs.nil?

    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def record_review(revid, grade, review)
    rs = @db.get_first_row('SELECT * FROM reviews WHERE revid = ?', [revid])
    if rs.nil?
      @db.execute('INSERT INTO reviews (revid, grade, review) VALUES (?, ?, ?)', [revid, grade, review])
      Logger.print "review #{grade} #{review} created for #{revid} assignment"
    else
      @db.execute('UPDATE reviews SET grade = ?, review = ? WHERE revid = ?', [grade, review, revid])
      Logger.print "review #{grade} #{review} updated for #{revid} assignment"
    end
    rs = @db.get_first_row('SELECT * FROM reviews WHERE revid = ?', [revid])
    rs[0]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def query_review(revid)
    rs = @db.get_first_row('SELECT * FROM reviews WHERE revid = ?', [revid])
    return rs if rs.nil?

    [rs[0], rs[1], rs[2], rs[3]]
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  private def collect_reviews(rs)
    reviews = []
    return reviews if rs.nil?

    rs.each do |row|
      Logger.print row
      next if row[1].nil? or row[2].nil? or row[3].nil?

      reviews.append Review.new(row[0], row[1], row[2], row[3])
    end
    reviews
  end

  def allreviews(uqid)
    multiline = <<-SQL
      SELECT * FROM reviews
      INNER JOIN userreviews ON reviews.revid = userreviews.id
      WHERE userreviews.uqid = ?;
    SQL
    rs = @db.execute(multiline, [uqid])
    collect_reviews(rs)
  rescue SQLite3::Exception => e
    puts "#{__FILE__}:#{__LINE__}:#{e}"
    close
    exit(1)
  end

  def close
    @db.close if @db
  end
end
