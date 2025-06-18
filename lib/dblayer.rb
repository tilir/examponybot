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
require_relative 'logger'

class DBLayer
  include Schema

  def initialize(dbname)
    @dbname = dbname
    setup_database
  end

  def clear_all!
    Logger.print "Clear all"
    if in_memory_db? || @db.nil?
      reconnect_database
    else
      clear_tables
    end
    initialize_managers
  end

  # Public interface for managers
  def execute(query, *params)
    safe_sql { @db.execute(query, params) }
  end

  def get_first_row(query, *params)
    safe_sql { @db.get_first_row(query, params) }
  end

  def get_first_value(query, *params)
    safe_sql { @db.get_first_value(query, params) }
  end

  def transaction(&block)
    safe_sql { @db.transaction(&block) }
  end

  # Access to managers
  attr_reader :users, :questions, :exams, :user_questions, :answers, :reviews

  def close
    @db.close if @db
  end

  private

  def setup_database
    @db = SQLite3::Database.new(@dbname)
    @db.results_as_hash = false
    create_schema(@db)
    initialize_managers
  end

  def reconnect_database
    @db.close if @db
    setup_database
  end

  def clear_tables
    transaction do
      execute("PRAGMA foreign_keys = OFF")
      get_user_tables.each { |t| execute("DELETE FROM #{t}") }
      execute("DELETE FROM sqlite_sequence")
      execute("PRAGMA foreign_keys = ON")
    end
  end

  def get_user_tables
    execute("SELECT name FROM sqlite_master WHERE type='table'")
      .flatten
      .reject { |t| t.start_with?('sqlite_') }
  end

  def in_memory_db?
    @dbname == ':memory:'
  end

  def initialize_managers
    @users = UserManager.new(self)
    @questions = QuestionManager.new(self)
    @exams = ExamManager.new(self)
    @user_questions = UserQuestionManager.new(self)
    @answers = AnswerManager.new(self)
    @reviews = ReviewManager.new(self)
  end

  def safe_sql
    yield
  rescue SQLite3::Exception => e
    Logger.print "SQL Error: #{e.message}"
    Logger.print "Query: #{e.query}" if e.respond_to?(:query)
    raise DBLayerError, "Database operation failed"
  end
end

class UserManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?
    @db = db_layer
  end
  
  def add_user(tguser, priv, name)
    raise ArgumentError, 'tguser, priv and name must not be nil' if tguser.nil? || priv.nil? || name.nil?
    
    # First, check if the user already exists
    existing = get_user_by_id(tguser)
    
    if existing
      # Update the existing record
      @db.execute(
        'UPDATE users SET username = ?, privlevel = ? WHERE userid = ?',
        name, priv, tguser
      )
    else
      # Create a new user
      @db.execute(
        'INSERT INTO users (userid, username, privlevel) VALUES (?, ?, ?)',
        tguser, name, priv
      )
    end
    
    get_user_by_id(tguser)
  end
  
  def get_user_by_id(userid)
    row = @db.get_first_row(
      'SELECT id, userid, username, privlevel FROM users WHERE userid = ?', 
      userid
    )
    row.nil? ? nil : DBUser.from_db_row(row)
  end
  
  def users_empty?
    not any?
  end

  def any?
    @db.get_first_value('SELECT 1 FROM users LIMIT 1') == 1
  end

  def all_users
    @db.execute('SELECT id, userid, username, privlevel FROM users')
      .map { |row| DBUser.from_db_row(row) }
  end
  
  def all_nonpriv_users
    @db.execute('SELECT id, userid, username, privlevel FROM users WHERE privlevel = 1')
      .map { |row| DBUser.from_db_row(row) }
  end

  alias_method :all, :all_users
  alias_method :all_nonpriv, :all_nonpriv_users
  alias_method :empty?, :users_empty?
end

class QuestionManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?
    @db = db_layer
  end
  
  def add_question(number, variant, question)
    # First check if question exists
    exists = @db.get_first_value(
      'SELECT 1 FROM questions WHERE number = ? AND variant = ?',
      number, variant
    )

    if exists
      @db.execute(
        'UPDATE questions SET question = ? WHERE number = ? AND variant = ?',
        question, number, variant
      )
      Logger.print "Question #{number} variant #{variant} updated: #{question}"
    else
      @db.execute(
        'INSERT INTO questions (number, variant, question) VALUES (?, ?, ?)',
        number, variant, question
      )
      Logger.print "Question #{number} variant #{variant} added: #{question}"
    end

    # Return the current state
    get_question(number, variant)    
  end
  
  def all_questions
    @db.execute('SELECT id, number, variant, question FROM questions')
      .map { |row| DBQuestion.from_db_row(row) }
  end
  
  def get_question(number, variant)
    row = @db.get_first_row(
      'SELECT id, number, variant, question FROM questions WHERE number = ? AND variant = ?',
      number, variant
    )
    row.nil? ? nil : DBQuestion.from_db_row(row)
  end
  
  def n_questions
    @db.get_first_value('SELECT MAX(number) FROM questions')
  end
  
  def n_variants
    @db.get_first_value('SELECT MAX(variant) FROM questions')
  end

  alias_method :find, :get_question
  alias_method :add, :add_question
  alias_method :all, :all_questions
end

class ExamManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?
    @db = db_layer
  end

  def any?
    @db.get_first_value('SELECT 1 FROM exams LIMIT 1') == 1
  end
  
  def exams_empty?
    @db.get_first_value('SELECT COUNT(*) FROM exams') == 0
  end
  
  def add_exam(name)
    if exams_empty?
      @db.execute('INSERT INTO exams (state, name) VALUES (?, ?)', 0, name)
      Logger.print "exam #{name} added"
      find_by_name(name)
    else
      Logger.print 'sorry only one exam supported'
      nil
    end
  end
  
  def find_by_name(name)
    row = @db.get_first_row('SELECT id, state, name FROM exams WHERE name = ?', name)
    row.nil? ? nil : DBExam.from_db_row(row)
  end

  def set_exam_state(name, state)
    row = @db.get_first_row('SELECT id FROM exams WHERE name = ?', name)
    return nil if row.nil?
    
    @db.execute('UPDATE exams SET state = ? WHERE id = ?', state, row[0])
    row = @db.get_first_row('SELECT id, state, name FROM exams WHERE id = ?', row[0])
    DBExam.from_db_row(row)
  end

  alias_method :empty?, :exams_empty?
end

class UserQuestionManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?
    @db = db_layer
  end

  def register_question(eid, uid, qid)
    raise ArgumentError, 'qid cannot be nil' if qid.nil?

    row = @db.get_first_row(
      'SELECT id FROM userquestions WHERE exam = ? AND user = ? AND question = ?',
      eid, uid, qid
    )
    
    if row.nil?
      @db.execute('INSERT INTO userquestions (exam, user, question) VALUES (?, ?, ?)', eid, uid, qid)
      Logger.print "question #{qid} linked with user #{uid}"
      row = @db.get_first_row(
        'SELECT id, exam, user, question FROM userquestions WHERE exam = ? AND user = ? AND question = ?',
        eid, uid, qid
      )
    else
      Logger.print "question #{qid} link with user #{uid} already exists"
      row = @db.get_first_row('SELECT id, exam, user, question FROM userquestions WHERE id = ?', row[0])
    end
    
    row.nil? ? nil : DBUserQuestion.from_db_row(row)
  end

  def user_nth_question(eid, uid, n)
    row = @db.get_first_row('SELECT id FROM questions WHERE number = ?', n)
    return nil if row.nil?
    
    qid = row[0]
    row = @db.get_first_row(
      'SELECT id, exam, user, question FROM userquestions WHERE exam = ? AND user = ? AND question = ?',
      eid, uid, qid
    )
    row.nil? ? nil : DBUserQuestion.from_db_row(row)
  end

  alias_method :register, :register_question
end

class AnswerManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?
    @db = db_layer
  end

  def record_answer(uqid, t)
    row = @db.get_first_row('SELECT id FROM answers WHERE uqid = ?', uqid)
    
    if row.nil?
      @db.execute('INSERT INTO answers (uqid, answer) VALUES (?, ?)', uqid, t)
      Logger.print "answer #{t} recorded for #{uqid}"
      row = @db.get_first_row('SELECT id, uqid, answer FROM answers WHERE uqid = ?', uqid)
    else
      @db.execute('UPDATE answers SET answer = ? WHERE id = ?', t, row[0])
      Logger.print "answer #{t} updated for #{uqid}"
      row = @db.get_first_row('SELECT id, uqid, answer FROM answers WHERE id = ?', row[0])
    end
    
    DBAnswer.from_db_row(row)
  end

  def uqid_to_answer(uqid)
    row = @db.get_first_row('SELECT id, uqid, answer FROM answers WHERE uqid = ?', uqid)
    row.nil? ? nil : DBAnswer.from_db_row(row)
  end

  def awid_to_userquestion(awid)
    row = @db.get_first_row('SELECT uqid FROM answers WHERE id = ?', awid)
    return nil if row.nil?
    
    row = @db.get_first_row('SELECT id, exam, user, question FROM userquestions WHERE id = ?', row[0])
    dbu = DBUserQuestion.from_db_row(row)
    UserQuestion.new(@db, dbu.exam_id, dbu.user_id, dbu.question_id) 
  end

  def uqid_to_question(uqid)
    row = @db.get_first_row('SELECT question FROM userquestions WHERE id = ?', uqid)
    return nil if row.nil?
    
    row = @db.get_first_row('SELECT id, number, variant, question FROM questions WHERE id = ?', row[0])
    DBQuestion.from_db_row(row)
  end

  def user_all_answers(uid)
    query = <<-SQL
      SELECT answers.* FROM userquestions
      INNER JOIN answers ON userquestions.id = answers.uqid
      WHERE userquestions.user = ?
    SQL
    @db.execute(query, uid).map { |row| DBAnswer.from_db_row(row) }
  end

  def all_answered_users
    query = <<-SQL
      SELECT DISTINCT users.* FROM userquestions
      INNER JOIN users ON users.id = userquestions.user
      INNER JOIN answers ON userquestions.id = answers.uqid
    SQL
    @db.execute(query).map { |row| User.from_db_user(@db, DBUser.from_db_row(row)) }
  end

  alias_method :create_or_update, :record_answer
  alias_method :find_by_user_question, :uqid_to_answer
  alias_method :find_by_answer, :awid_to_userquestion
end

class ReviewManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?
    @db = db_layer
  end

  def nreviews(rid)
    query = <<-SQL
      SELECT COUNT(reviews.id) 
      FROM reviews 
      INNER JOIN userreviews ON reviews.revid = userreviews.id 
      WHERE userreviews.reviewer = ?
    SQL
    @db.get_first_value(query, rid)
  end

  def create_review_assignment(rid, uqid)
    row = @db.get_first_row(
      'SELECT id FROM userreviews WHERE reviewer = ? AND uqid = ?',
      rid, uqid
    )
    
    if row.nil?
      @db.execute('INSERT INTO userreviews (reviewer, uqid) VALUES (?, ?)', rid, uqid)
      Logger.print "uqid #{uqid} linked with reviewer #{rid}"
      row = @db.get_first_row(
        'SELECT id, reviewer, uqid FROM userreviews WHERE reviewer = ? AND uqid = ?',
        rid, uqid
      )
    else
      Logger.print "uqid #{uqid} link with reviewer #{rid} already exists"
      row = @db.get_first_row('SELECT id, reviewer, uqid FROM userreviews WHERE id = ?', row[0])
    end
    
    DBUserReview.from_db_row(row)
  end

  def urid_to_uqid(uid, rid)
    row = @db.get_first_row(
      'SELECT uqid FROM userreviews WHERE reviewer = ? AND id = ?',
      uid, rid
    )
    row.nil? ? nil : row[0]
  end

  def record_review(revid, grade, review)
    row = @db.get_first_row('SELECT id FROM reviews WHERE revid = ?', revid)
    
    if row.nil?
      @db.execute('INSERT INTO reviews (revid, grade, review) VALUES (?, ?, ?)', revid, grade, review)
      Logger.print "review #{grade} #{review} created for #{revid} assignment"
      row = @db.get_first_row('SELECT id, revid, grade, review FROM reviews WHERE revid = ?', revid)
    else
      @db.execute('UPDATE reviews SET grade = ?, review = ? WHERE revid = ?', grade, review, revid)
      Logger.print "review #{grade} #{review} updated for #{revid} assignment"
      row = @db.get_first_row('SELECT id, revid, grade, review FROM reviews WHERE id = ?', row[0])
    end
    
    DBReview.from_db_row(row)
  end

  def query_review(revid)
    row = @db.get_first_row(
      'SELECT id, revid, grade, review FROM reviews WHERE revid = ?',
      revid
    )
    row.nil? ? nil : DBReview.from_db_row(row)
  end

  def allreviews(uqid)
    query = <<-SQL
      SELECT reviews.* FROM reviews
      INNER JOIN userreviews ON reviews.revid = userreviews.id
      WHERE userreviews.uqid = ?
    SQL
    @db.execute(query, uqid).map { |row| DBReview.from_db_row(row) }
  end

  alias_method :assign_reviewer, :create_review_assignment
  alias_method :submit, :record_review
  alias_method :count_by_user, :nreviews
  alias_method :find_by_assignment, :query_review
end
