#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Basic tests for dblayer
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'dblayer'

describe 'Database Layer' do
  before do
    @db = DBLayer.new(':memory:')
  end

  after do
    @db.close
  end

  describe 'User operations' do
    it 'adds and retrieves a user' do
      user = User.new(@db, 123, UserStates.to_i(:regular), 'Alice')
      assert user.id.is_a?(Integer)

      found = @db.users.get_user_by_id(123)
      assert_equal 'Alice', found.username
      assert_equal UserStates.to_i(:regular), found.privlevel
    end

    it 'updates existing user' do
      user1 = User.new(@db, 123, UserStates.to_i(:regular), 'Alice')
      user2 = User.new(@db, 123, UserStates.to_i(:privileged), 'Alice Updated')

      assert_equal user1.id, user2.id
      assert_equal 'Alice Updated', user2.username
      assert user2.privileged?
    end
  end

  describe 'Question operations' do
    it 'adds and finds a question' do
      q = Question.new(@db, 1, 1, 'What is Ruby?')
      found = @db.questions.find(1, 1)

      assert_equal q.text, found.question
    end

    it 'updates existing question' do
      q1 = Question.new(@db, 1, 1, 'Old text')
      q2 = Question.new(@db, 1, 1, 'New text')

      assert_equal q1.id, q2.id
      assert_equal 'New text', q2.text
    end
  end

  describe 'Exam operations' do
    it 'creates and manages exams' do
      exam = Exam.new(@db, 'Final Exam')
      assert_equal :stopped, exam.state

      exam.set_state(:answering)
      assert_equal :answering, exam.state
    end
  end

  describe 'UserQuestion operations' do
    before do
      @user = User.new(@db, 1, UserStates.to_i(:regular), 'Test User')
      @question = Question.new(@db, 1, 1, 'Q?')
      @exam = Exam.new(@db, 'Test Exam')
    end

    it 'links user with question' do
      uq = UserQuestion.new(@db, @exam.id, @user.id, @question.id)
      assert_equal @question.id, uq.question_id
    end

    it 'finds user questions by number' do
      UserQuestion.new(@db, @exam.id, @user.id, @question.id)
      found = @db.user_questions.user_nth_question(@exam.id, @user.id, 1)

      assert_equal @question.id, found.question_id
    end
  end

  describe 'Answer operations' do
    before do
      user = User.new(@db, 1, 1, 'U')
      question = Question.new(@db, 1, 1, 'Q')
      exam = Exam.new(@db, 'E')
      @uq = UserQuestion.new(@db, exam.id, user.id, question.id)
    end

    it 'records and finds answers' do
      answer = Answer.new(@db, @uq.id, '42')
      assert_equal '42', answer.text

      found = @db.answers.find_by_user_question(@uq.id)
      assert_equal answer.answer, found.answer
    end
  end

  describe 'Review operations' do
    before do
      user = User.new(@db, 1, 1, 'Student')
      reviewer = User.new(@db, 2, UserStates.to_i(:privileged), 'Teacher')
      question = Question.new(@db, 1, 1, 'Q')
      exam = Exam.new(@db, 'E')
      @uq = UserQuestion.new(@db, exam.id, user.id, question.id)
      @assignment = UserReview.new(@db, reviewer.id, @uq.id)
    end

    it 'creates and queries reviews' do
      review = Review.new(@db, @assignment.id, 5, 'Good work')
      assert_equal 5, review.grade

      found = @db.reviews.query_review(@assignment.id)
      assert_equal review.text, found.review
    end

    it 'counts reviews per reviewer' do
      Review.new(@db, @assignment.id, 4, 'Not bad')
      assert_equal 1, @db.reviews.nreviews(@assignment.reviewer_id)
    end
  end
end
