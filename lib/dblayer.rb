# frozen_string_literal: true

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
    Logger.print 'Clear all'
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

  def dumpdb
    log_database_contents @db if @db
  end

  # Access to managers
  attr_reader :users, :questions, :exams, :user_questions, :answers, :reviews

  def close
    @db&.close
  end

  private

  def setup_database
    @db = SQLite3::Database.new(@dbname)
    @db.results_as_hash = false
    create_schema(@db)
    initialize_managers
  end

  def reconnect_database
    @db&.close
    setup_database
  end

  def clear_tables
    transaction do
      execute('PRAGMA foreign_keys = OFF')
      get_user_tables.each { |t| execute("DELETE FROM #{t}") }
      execute('DELETE FROM sqlite_sequence')
      execute('PRAGMA foreign_keys = ON')
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
    raise DBLayerError, 'Database operation failed'
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
    !any?
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

  alias all all_users
  alias all_nonpriv all_nonpriv_users
  alias empty? users_empty?
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

  alias find get_question
  alias add add_question
  alias all all_questions
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
    @db.get_first_value('SELECT COUNT(*) FROM exams').zero?
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

  alias empty? exams_empty?
end

class UserQuestionManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?

    @db = db_layer
  end

  def all
    @db.execute('SELECT * FROM userquestions')
       .map { |row| DBUserQuestion.from_db_row(row) }
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
      raise 'row cannot be nil' if row.nil?
    end

    row.nil? ? nil : DBUserQuestion.from_db_row(row)
  end

  def user_nth_question(exam_id, user_id, question_number)
    query = <<~SQL
      SELECT uq.id, uq.exam, uq.user, uq.question
      FROM userquestions uq
      JOIN questions q ON uq.question = q.id
      WHERE uq.exam = ?#{' '}
        AND uq.user = ?#{' '}
        AND q.number = ?
    SQL

    rows = @db.execute(query, exam_id, user_id, question_number)

    case rows.size
    when 0
      Logger.print("Question not found: exam=#{exam_id}, user=#{user_id}, number=#{question_number}")
      nil
    when 1
      DBUserQuestion.from_db_row(rows.first)
    else
      raise "Found #{rows.size} questions for user #{user_id}, exam #{exam_id}, number #{question_number}"
    end
  end

  alias register register_question
end

class AnswerManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?

    @db = db_layer
  end

  def all
    @db.execute('SELECT * FROM answers')
       .map { |row| DBAnswer.from_db_row(row) }
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
    Logger.print "Query all answers for user #{uid}"
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
    @db.execute(query).map { |row| DBUser.from_db_row(row) }
  end

  def user_answer_stats
    query = <<~SQL
      SELECT#{' '}
        u.userid, u.username,
        COUNT(a.id) AS total_answers,
        GROUP_CONCAT(DISTINCT uq.question) AS answered_questions
      FROM users u
      INNER JOIN userquestions uq ON u.id = uq.user
      INNER JOIN answers a ON uq.id = a.uqid
      WHERE u.privlevel = 1
      GROUP BY u.id
    SQL

    @db.execute(query).map do |row|
      {
        telegram_id: row[0],
        username: row[1],
        total_answers: row[2],
        answered_questions: row[3]&.split(',')&.map(&:to_i) || []
      }
    end
  end

  alias create_or_update record_answer
  alias find_by_user_question uqid_to_answer
  alias find_by_answer awid_to_userquestion
end

class ReviewManager
  def initialize(db_layer)
    raise ArgumentError, 'DB layer cannot be nil' if db_layer.nil?

    @db = db_layer
  end

  def nreviews(rid)
    query = <<-SQL
      SELECT COUNT(reviews.id)#{' '}
      FROM reviews#{' '}
      INNER JOIN userreviews ON reviews.revid = userreviews.id#{' '}
      WHERE userreviews.reviewer = ?
    SQL
    @db.get_first_value(query, rid)
  end

  def tguser_reviews(tgid)
    query = <<-SQL
      SELECT reviews.id, reviews.revid, reviews.grade, reviews.review
      FROM reviews
      INNER JOIN userreviews ON reviews.revid = userreviews.id
      INNER JOIN users ON userreviews.reviewer = users.id
      WHERE users.userid = ?
    SQL
    @db.execute(query, tgid).map { |row| DBReview.from_db_row(row) }
  end

  def detailed_reviews_for_user(tgid)
    query = <<~SQL
      SELECT#{' '}
        r.id, r.grade, r.review,
        rev.userid AS reviewer_id,
        q.number AS question_num
      FROM reviews r
      INNER JOIN userreviews ur ON r.revid = ur.id
      INNER JOIN users rev ON ur.reviewer = rev.id
      INNER JOIN userquestions uq ON ur.uqid = uq.id
      INNER JOIN users target ON uq.user = target.id
      INNER JOIN questions q ON uq.question = q.id
      WHERE target.userid = ?
    SQL

    @db.execute(query, tgid).map do |row|
      {
        id: row[0],
        grade: row[1],
        text: row[2],
        reviewer: row[3],
        question: row[4]
      }
    end
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

  def user_review_stats
    query = <<~SQL
      SELECT#{' '}
        u.userid,
        u.username,
        COUNT(r.id) AS total_reviews,
        GROUP_CONCAT(DISTINCT ur.uqid) AS reviewed_answers
      FROM users u
      INNER JOIN userreviews ur ON u.id = ur.reviewer
      INNER JOIN reviews r ON ur.id = r.revid
      WHERE u.privlevel = 1
      GROUP BY u.id
    SQL

    @db.execute(query).map do |row|
      {
        telegram_id: row[0],
        username: row[1],
        total_reviews: row[2],
        reviewed_answers: row[3]&.split(',')&.map(&:to_i) || []
      }
    end
  end

  # @param telegram_user_id [Integer] Telegram user ID (users.userid)
  # @return [Array<Hash>] Review assignments with:
  #   - :question [DBQuestion]
  #   - :answer [DBAnswer, nil]
  #   - :assignment [DBUserReview]
  def get_review_assignments(telegram_user_id)
    query = <<~SQL
      SELECT#{' '}
        -- Question data
        q.id AS qid,
        q.number AS q_number,
        q.variant AS q_variant,
        q.question AS q_text,
      #{'  '}
        -- Answer data
        a.id AS a_id,
        a.answer AS a_text,
      #{'  '}
        -- Answer author data
        ua.id AS author_id,
        ua.userid AS author_telegram_id,
        ua.username AS author_username,
      #{'  '}
        -- Review assignment data
        ur.id AS ur_id,
        ur.reviewer AS reviewer_internal_id,
        ur.uqid AS uqid
      FROM userreviews ur
      JOIN users ur_user ON ur.reviewer = ur_user.id
      JOIN userquestions uq ON ur.uqid = uq.id
      JOIN questions q ON uq.question = q.id
      LEFT JOIN answers a ON a.uqid = uq.id
      JOIN users ua ON uq.user = ua.id  -- Author of the answer
      WHERE ur_user.userid = ?
    SQL

    @db.execute(query, telegram_user_id).map do |row|
      {
        question: DBQuestion.new(row[0], row[1], row[2], row[3]),
        answer: row[4] ? DBAnswer.new(row[4], row[8], row[5]) : nil, # row[8] is uqid
        author: {
          id: row[6],
          telegram_id: row[7],
          username: row[8]
        },
        assignment: DBUserReview.new(row[9], row[10], row[11])
      }
    end
  end

  alias assign_reviewer create_review_assignment
  alias submit record_review
  alias count_by_user nreviews
  alias find_by_assignment query_review
  alias all_for_answer allreviews
end
