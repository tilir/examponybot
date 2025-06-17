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

require_relative 'examstate'
require_relative 'userstate'
require_relative 'schema'

class User < DBUser
  UserStates::STATES.each_key do |state|
    define_method("#{state}?") { privlevel == UserStates.to_i(state) }
  end

  def self.from_db_user(db_layer, db_user)
    raise ArgumentError, 'DB layer must be provided' if db_layer.nil?
    raise ArgumentError, 'DBUser must be provided' if db_user.nil?

    user = allocate  # Создаем неинициализированный объект
    user.instance_variable_set(:@db, db_layer)
    user.instance_variable_set(:@id, db_user.id)
    user.instance_variable_set(:@userid, db_user.userid)
    user.instance_variable_set(:@username, db_user.username)
    user.instance_variable_set(:@privlevel, db_user.privlevel)
    user
  end

  def initialize(db_layer, userid, privlevel = nil, username = nil)
    raise ArgumentError, 'db_layer and userid shall not be nil' if db_layer.nil? || userid.nil?
    @db = db_layer
    
    if username && privlevel
      # Create new user mode
      privlevel = UserStates.to_i(privlevel) if privlevel.is_a?(Symbol)
      db_user = @db.users.add_user(userid, privlevel, username)
      super(db_user.id, db_user.userid, db_user.username, db_user.privlevel)
    else
      # Load existing user mode
      db_user = @db.users.get_user_by_id(userid)
      if db_user
        super(db_user.id, db_user.userid, db_user.username, db_user.privlevel)
      else
        @privlevel = UserStates.to_i(:nonexistent)
      end
    end
  end

  def level
    UserStates.to_sym(privlevel)
  end

  def nth_question(exam_id, question_number)
    uq = @db.user_questions.user_nth_question(exam_id, id, question_number)
    return nil unless uq
    
    UserQuestion.new(@db, uq.exam_id, uq.user_id, uq.question_id)
  end

  def review_count
    @db.reviews.count_by_user(id)
  end

  def all_answers
    @db.answers.user_all_answers(id).map do |answer|
      Answer.new(@db, answer.user_question_id, answer.answer)
    end
  end

  def to_userquestion(review_id)
    @db.reviews.urid_to_uqid(id, review_id)
  end

  def to_s
    <<~USER_INFO.chomp
      User: #{id || '(not in DB)'}
      \tUserID: #{userid}
      \tUsername: #{username || '(none)'}
      \tPrivilege: #{level} (#{privlevel})
    USER_INFO
  end
end

class Question < DBQuestion
  def initialize(db_layer, number, variant, text = nil)
    @db = db_layer
    
    if text
      # Create new question mode
      db_question = @db.questions.add_question(number, variant, text)
      super(db_question.id, db_question.number, db_question.variant, db_question.question)
    else
      # Load existing question mode
      db_question = @db.questions.get_question(number, variant)
      raise "Question #{number}/#{variant} not found" unless db_question
      super(db_question.id, db_question.number, db_question.variant, db_question.question)
    end
  end

  def to_s
    <<~TEXT.chomp
      Question #{id}:
      \tNumber:  #{number}
      \tVariant: #{variant}
      \tText:    #{question}
    TEXT
  end

  # Alias for backward compatibility
  alias_method :text, :question
end

class Exam < DBExam
  def initialize(db_layer, name)
    raise ArgumentError, 'DB layer must be provided' if db_layer.nil?
    raise ArgumentError, 'Exam name must be provided' if name.nil? || name.empty?

    @db = db_layer
    
    # First try to find existing exam
    db_exam = @db.exams.find_by_name(name)
    
    # If not found - create new one
    unless db_exam
      db_exam = @db.exams.add_exam(name)
      raise "Exam creation failed" unless db_exam
    end

    # Initialize parent class
    super(db_exam.id, db_exam.state, db_exam.name)
  end

  def state
    ExamStates.to_sym(super)
  end

  def set_state(new_state)
    code = ExamStates.to_i(new_state)
    updated_exam = @db.exams.set_exam_state(name, code)
    @state = code # Обновляем внутреннее состояние
    updated_exam
  end

  def to_s
    <<~EXAM.chomp
      Exam: #{id}
      \tName: #{name}
      \tState: #{state} (#{@state})
    EXAM
  end
end

class UserQuestion < DBUserQuestion
  def initialize(db_layer, exam_id, user_id, question_id)
    raise ArgumentError, 'question_id cannot be nil' if question_id.nil?

    db_user_question = db_layer.user_questions.register(exam_id, user_id, question_id)
    super(db_user_question.id, db_user_question.exam_id, db_user_question.user_id, db_user_question.question_id)
    @db = db_layer
  end

  def answer
    db_answer = @db.answers.find_by_user_question(id)
    db_answer ? Answer.new(@db, db_answer.user_question_id, db_answer.answer) : nil
  end

  def question
    db_question = @db.answers.uqid_to_question(id)
    db_question ? Question.new(@db, db_question.number, db_question.variant, db_question.question) : nil
  end

  def to_s
    <<~TEXT.chomp
      UserQuestion #{id}:
      \tExam: #{exam_id}
      \tUser: #{user_id}
      \tQuestion: #{question_id}
    TEXT
  end

  # Just compatibility
  alias_method :examid, :exam_id
  alias_method :userid, :user_id
  alias_method :questionid, :question_id
  alias_method :to_answer, :answer
  alias_method :to_question, :question
end

class Answer < DBAnswer
  def initialize(db_layer, uqid, text = nil)
    @db = db_layer
    
    db_answer = 
      if text
        @db.answers.create_or_update(uqid, text)
      else
        @db.answers.find_by_user_question(uqid) || 
          raise("Answer not found for UQID #{uqid}")
      end

    # Initialize the parent class with data from the database
    super(db_answer.id, db_answer.user_question_id, db_answer.answer)
  end

  def question
    user_question = @db.answers.find_by_answer(id)
    raise "Answer not registered" unless user_question
    
    user_question.question
  end

  def reviews
    @db.reviews.all_for_answer(uqid)
  end

  def to_s
    <<~TEXT.chomp
      Answer #{id}:
      \tUserQuestion: #{user_question_id}
      \tText: #{answer}
    TEXT
  end

  # Just compatibility
  alias_method :to_question, :question
  alias_method :all_reviews, :reviews
  alias_method :text, :answer
  alias_method :uqid, :user_question_id
end

class UserReview < DBUserReview
  def initialize(db_layer, reviewer_id, user_question_id)
    db_review = db_layer.reviews.assign_reviewer(reviewer_id, user_question_id)
    super(db_review.id, db_review.reviewer_id, db_review.user_question_id)
    @db = db_layer
  end

  # Для совместимости
  alias_method :userid, :reviewer_id
  alias_method :userquestionid, :user_question_id

  def to_s
    <<~TEXT.chomp
      UserReview #{id}:
      \tReviewer: #{reviewer_id}
      \tUserQuestion: #{user_question_id}
    TEXT
  end
end

class Review < DBReview
  def initialize(db_layer, review_assignment_id, grade = nil, text = nil)
    @db = db_layer
    
    db_review = if grade && text
                  @db.reviews.submit(review_assignment_id, grade, text)
                else
                  @db.reviews.find_by_assignment(review_assignment_id) ||
                  raise("Review not found for assignment #{review_assignment_id}")
                end

    # Инициализируем родительский класс
    super(db_review.id, db_review.user_review_id, db_review.grade, db_review.review)
  end

  def to_s
    <<~TEXT.chomp
      Review #{id}:
      \tAssignment: #{user_review_id}
      \tGrade: #{grade}
      \tText: #{review}
    TEXT
  end

  alias_method :revid, :user_review_id
  alias_method :text, :review
end