# frozen_string_literal: true

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
#
# Database Schema Relationships:
#
# users ||--o{ userquestions : "user→id"
#           | id (PK)
#           | userid (UNIQUE, Telegram ID)  
#           | username
#           | privlevel (0-nonexistent, 1-regular, 2-privileged)
#
# questions ||--o{ userquestions : "question→id"
#             | id (PK)
#             | number (question #)
#             | variant (version #)  
#             | question (text)
#             UNIQUE(number, variant)
#
# exams ||--o{ userquestions : "exam→id"
#         | id (PK)
#         | state (0-stopped, 1-answering, 2-reviewing, 3-grading)
#         | name
#
# userquestions }o--|| answers : "uqid→id"
#                  | id (PK)
#                  | exam_id (FK)
#                  | user_id (FK)
#                  | question_id (FK)
#
# userquestions }o--|| userreviews : "uqid→id"
#
# userreviews }o--|| reviews : "revid→id"
#               | id (PK)
#               | reviewer_id (FK to users)
#               | uqid (FK to userquestions)
#
# reviews
#       | id (PK)
#       | revid (FK to userreviews)
#       | grade (1-10)
#       | review (text)
#
# Key Business Rules:
# 1. Each exam has multiple user-question assignments
# 2. Each user-question pair has exactly one answer
# 3. Each answer receives 2-3 reviews (N_REVIEWERS)
# 4. Question variants are randomized per user
# 5. Privilege levels control command access
#
#------------------------------------------------------------------------------

class DBLayerError < StandardError
end

module Schema
  def create_schema(db)
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
      question TEXT,
      UNIQUE(number, variant) ON CONFLICT REPLACE
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

# Represents a user in the peer assessment system
class DBUser
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] userid
  #   @return [Integer] Telegram user ID (unique platform identifier)
  #   @example 123456789
  attr_reader :userid

  # @!attribute [r] username
  #   @return [String, nil] Display name from Telegram (optional)
  attr_reader :username

  # @!attribute [r] privlevel
  #   @return [Integer] Access level (0-2):
  #     - 0 :nonexistent - Unregistered user
  #     - 1 :regular - Standard participant
  #     - 2 :privileged - Admin/teacher
  attr_reader :privlevel

  def initialize(id, userid, username, privlevel)
    @id = id
    @userid = userid
    @username = username
    @privlevel = privlevel
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

# Represents an exam question with variants
class DBQuestion
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] number
  #   @return [Integer] Question sequence number (1-based)
  #   @example 3 # Third question in exam
  attr_reader :number

  # @!attribute [r] variant
  #   @return [Integer] Version number of this question (1-based)
  #   @example 2 # Second variant of this question
  attr_reader :variant

  # @!attribute [r] question
  #   @return [String] Full question text content
  attr_reader :question

  def initialize(id, number, variant, question)
    @id = id
    @number = number
    @variant = variant
    @question = question
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

# Represents an exam instance
class DBExam
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] state
  #   @return [Integer] Current workflow state:
  #     - 0 :stopped - Not active
  #     - 1 :answering - Accepting answers
  #     - 2 :reviewing - In peer review phase
  #     - 3 :grading - Completed
  attr_reader :state

  # @!attribute [r] name
  #   @return [String] Human-readable exam identifier
  #   @example "Midterm 2024"
  attr_reader :name

  def initialize(id, state, name)
    @id = id
    @state = state
    @name = name
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2])
  end
end

# Junction table linking users to their assigned questions
class DBUserQuestion
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] exam_id
  #   @return [Integer] Foreign key to DBExam
  attr_reader :exam_id

  # @!attribute [r] user_id
  #   @return [Integer] Foreign key to DBUser (student)
  attr_reader :user_id

  # @!attribute [r] question_id
  #   @return [Integer] Foreign key to DBQuestion
  attr_reader :question_id

  def initialize(id, exam_id, user_id, question_id)
    @id = id
    @exam_id = exam_id
    @user_id = user_id
    @question_id = question_id
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

# Represents a student's answer to a question
class DBAnswer
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] user_question_id
  #   @return [Integer] Foreign key to DBUserQuestion
  attr_reader :user_question_id

  # @!attribute [r] answer
  #   @return [String] Student's response text
  attr_reader :answer

  def initialize(id, user_question_id, answer)
    @id = id
    @user_question_id = user_question_id
    @answer = answer
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2])
  end
end

# Links reviewers to answers they must evaluate
class DBUserReview
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] reviewer_id
  #   @return [Integer] Foreign key to DBUser (reviewer)
  attr_reader :reviewer_id

  # @!attribute [r] user_question_id
  #   @return [Integer] Foreign key to DBUserQuestion (answer being reviewed)
  attr_reader :user_question_id

  def initialize(id, reviewer_id, user_question_id)
    @id = id
    @reviewer_id = reviewer_id
    @user_question_id = user_question_id
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2])
  end
end

# Contains evaluation data for peer reviews
class DBReview
  # @!attribute [r] id
  #   @return [Integer] Database primary key
  attr_reader :id

  # @!attribute [r] user_review_id
  #   @return [Integer] Foreign key to DBUserReview
  attr_reader :user_review_id

  # @!attribute [r] grade
  #   @return [Integer] Numeric score (1-10 scale)
  #   @example 8 # Good quality answer
  attr_reader :grade

  # @!attribute [r] review
  #   @return [String] Written feedback text
  attr_reader :review

  def initialize(id, user_review_id, grade, review)
    @id = id
    @user_review_id = user_review_id
    @grade = grade
    @review = review
  end

  def self.from_db_row(row)
    new(row[0], row[1], row[2], row[3])
  end
end

def log_database_contents(db)
  tables = %w[
    users
    questions
    exams
    userquestions
    answers
    userreviews
    reviews
  ]

  tables.each do |table|
    puts "--- Table: #{table} ---"
    rows = db.execute("SELECT * FROM #{table}")
    columns = db.execute("PRAGMA table_info(#{table})").map { |col| col[1] }

    if rows.empty?
      puts '(empty)'
    else
      rows.each_with_index do |row, idx|
        row_hash = columns.zip(row).to_h
        puts "#{idx + 1}. #{row_hash.inspect}"
      end
    end

    puts
  end
end
