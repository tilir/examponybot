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
require_relative 'schema'

class Logger
  @@verbose = false

  def self.set_verbose(value)
    @@verbose = !!value
  end

  def self.verbose?
    @@verbose
  end

  def self.print(message)
    puts(message) if @@verbose
  end
end

def safe_sql
  yield
rescue SQLite3::Exception => e
  puts "SQLite3 Error: #{e.class} - #{e.message}"
  puts "Backtrace:"
  e.backtrace.each { |line| puts "  #{line}" }
  close if respond_to?(:close)
  exit(1)
end

class DBLayer
  include Schema
  attr_reader :name

  def initialize(dbname)
    safe_sql do
      @db = SQLite3::Database.new(dbname)
      @name = dbname
      create_schema(self)
    end
  end

  def add_user(tguser, priv, name)
    safe_sql do
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
    end
  end

  def get_user_by_id(userid)
    safe_sql do
      rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [userid])
      return nil if rs.nil? or rs.empty?
      return rs
    end
  end

  def users_empty?
    safe_sql do
      rs = @db.execute('SELECT * FROM users')
      Logger.print 'user table empty' if rs.empty?
      rs.empty?
    end
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
    safe_sql do
      rs = @db.execute('SELECT * FROM users')
      collect_users(rs)
    end
  end

  def all_nonpriv_users
    safe_sql do
      rs = @db.execute('SELECT * FROM users WHERE privlevel = 1')
      collect_users(rs)
    end
  end

  def add_question(number, variant, question)
    safe_sql do
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
    end
  end

  def all_questions
    safe_sql do
      questions = []
      rs = @db.execute('SELECT * FROM questions')
      rs.each do |row|
        Logger.print row
        next if row[1].nil? or row[2].nil? or row[3].nil?

        questions.append Question.new(self, row[1], row[2])
      end
      questions
    end
  end

  def get_question(number, variant)
    safe_sql do
      rs = @db.get_first_row('SELECT * FROM questions WHERE number = ? AND variant = ?', [number, variant])
      return nil if rs.nil?

      Logger.print "got question info: #{rs[1]} #{rs[2]} #{rs[3]}"
      rs
    end
  end

  def n_questions
    safe_sql do
      rs = @db.get_first_row('SELECT MAX(number) FROM questions')
      rs[0]
    end
  end

  def n_variants
    safe_sql do
      rs = @db.get_first_row('SELECT MAX(variant) FROM questions')
      rs[0]
    end
  end

  def exams_empty?
    rs = @db.execute('SELECT * FROM exams')
    rs.empty?
  end

  def add_exam(name)
    safe_sql do
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
      rs
    end
  end

  def set_exam_state(name, state)
    safe_sql do
      rs = @db.get_first_row('SELECT * FROM exams WHERE name = ?', [name])
      @db.execute('UPDATE exams SET state = ? WHERE id = ?', [state, rs[0]])
    end
  end

  def register_question(eid, uid, qid)
    safe_sql do
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
    end
  end

  def user_nth_question(eid, uid, n)
    safe_sql do
      multiline = <<-SQL
        SELECT userquestions.exam, userquestions.user, userquestions.question FROM userquestions
        INNER JOIN questions ON userquestions.question = questions.id
        WHERE userquestions.exam = ? AND userquestions.user = ? AND questions.number = ?
      SQL
      rs = @db.get_first_row("#{multiline}", [eid, uid, n])
      rs
    end
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
    safe_sql do
      multiline = <<-SQL
        SELECT DISTINCT answers.* FROM userquestions
        INNER JOIN answers ON userquestions.id = answers.uqid
        WHERE userquestions.user = ?
      SQL
      rs = @db.execute(multiline, [uid])
      collect_answers(rs)
    end
  end

  def all_answered_users
    safe_sql do
      multiline = <<-SQL
        SELECT DISTINCT users.* FROM userquestions
        INNER JOIN users ON users.id = userquestions.user
        INNER JOIN answers ON userquestions.id = answers.uqid
      SQL
      rs = @db.execute(multiline)
      return nil if rs.nil?

      collect_users(rs)
    end
  end

  def record_answer(uqid, t)
    safe_sql do
      rs = @db.get_first_row('SELECT id FROM answers WHERE uqid = ?', [uqid])
      if rs.nil?
        @db.execute('INSERT INTO answers (uqid, answer) VALUES (?, ?)', [uqid, t])
        Logger.print "answer #{t} recorded for #{uqid}"
        rs = @db.get_first_row('SELECT id FROM answers WHERE uqid = ?', [uqid])
      else
        @db.execute('UPDATE answers SET answer = ? WHERE id = ?', [t, rs[0]])
        Logger.print "answer #{t} updated for #{uqid}"
      end
      rs[0]
    end
  end

  def uqid_to_answer(uqid)
    safe_sql do
      multiline = <<-SQL
        SELECT answers.id, answers.uqid, answers.answer FROM answers
        INNER JOIN userquestions ON userquestions.id = answers.uqid
        WHERE userquestions.id = ?
      SQL
      @db.get_first_row(multiline, [uqid])
    end
  end

  def awid_to_userquestion(awid)
    safe_sql do
      multiline = <<-SQL
        SELECT userquestions.exam, userquestions.user, userquestions.question FROM userquestions
        INNER JOIN answers ON userquestions.id = answers.uqid
        WHERE answers.id = ?
      SQL
      @db.get_first_row(multiline, [awid])
    end
  end

  def uqid_to_question(uqid)
    safe_sql do
      multiline = <<-SQL
        SELECT DISTINCT * FROM questions
        INNER JOIN userquestions ON questions.id = userquestions.question
        WHERE userquestions.id = ?#{'      '}
      SQL
      @db.get_first_row(multiline, [uqid])
    end
  end

  def nreviews(rid)
    safe_sql do
      multiline = <<-SQL
        SELECT COUNT(reviews.id) FROM reviews
        INNER JOIN userreviews ON reviews.revid = userreviews.id
        WHERE userreviews.reviewer = ?;
      SQL
      rs = @db.get_first_row(multiline, [rid])
      Logger.print "found #{rs[0]} reviews from #{rid}"
      rs[0]
    end
  end

  def create_review_assignment(rid, uqid)
    safe_sql do
      rs = @db.get_first_row('SELECT * FROM userreviews WHERE reviewer = ? AND uqid = ?', [rid, uqid])
      if rs.nil?
        @db.execute('INSERT INTO userreviews (reviewer, uqid) VALUES (?, ?)', [rid, uqid])
        Logger.print "uqid #{uqid} linked with reviewer #{rid}"
        rs = @db.get_first_row('SELECT * FROM userreviews WHERE reviewer = ? AND uqid = ?', [rid, uqid])
      else
        Logger.print "uqid #{uqid} link with reviewer #{rid} already exists"
      end
      rs[0]
    end
  end

  # userreview.userquestionid
  def urid_to_uqid(uid, rid)
    safe_sql do
      rs = @db.get_first_row('SELECT uqid FROM userreviews WHERE reviewer = ? AND id = ?', [uid, rid])
      return nil if rs.nil?
      rs[0]
    end
  end

  def record_review(revid, grade, review)
    safe_sql do
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
    end
  end

  def query_review(revid)
    safe_sql do
      @db.get_first_row('SELECT * FROM reviews WHERE revid = ?', [revid])
    end
  end

  private def collect_reviews(rs)
    safe_sql do
      reviews = []
      return reviews if rs.nil?

      rs.each do |row|
        Logger.print row
        next if row[1].nil? || row[2].nil? || row[3].nil?

        reviews.append Review.new(self, row[1], row[2], row[3])
      end
      reviews
    end
  end

  def allreviews(uqid)
    safe_sql do
      multiline = <<-SQL
        SELECT * FROM reviews
        INNER JOIN userreviews ON reviews.revid = userreviews.id
        WHERE userreviews.uqid = ?;
      SQL
      rs = @db.execute(multiline, [uqid])
      collect_reviews(rs)
    end
  end

  def close
    @db.close if @db
  end
end
