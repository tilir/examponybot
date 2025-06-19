#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for answer database descr
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'dbstructure'

describe 'UserQuestion and Answer Integration' do
  let(:db)          { Minitest::Mock.new }
  let(:exam_id)     { 1 }
  let(:user_id)     { 2 }
  let(:question_id) { 3 }
  let(:uq_id)       { 42 }
  let(:answer_id)   { 99 }
  let(:sample_text) { 'Sample answer text' }

  describe UserQuestion do
    it 'correctly registers user-question assignment' do
      # Setup mock expectations
      db.expect(:user_questions, db)
      db.expect(:register,
                DBUserQuestion.new(uq_id, exam_id, user_id, question_id),
                [exam_id, user_id, question_id])

      # Exercise
      uq = UserQuestion.new(db, exam_id, user_id, question_id)

      # Verify
      assert_equal uq_id, uq.id
      assert_equal exam_id, uq.exam_id
      assert_equal user_id, uq.user_id
      assert_equal question_id, uq.question_id
      db.verify
    end

    it 'returns nil when no answer exists' do
      # Setup
      db.expect(:user_questions, db)
      db.expect(:register, mock_user_question, [exam_id, user_id, question_id])
      db.expect(:answers, db)
      db.expect(:find_by_user_question, nil, [uq_id])

      # Exercise/Verify
      uq = UserQuestion.new(db, exam_id, user_id, question_id)
      assert_nil uq.answer
      db.verify
    end

    it 'returns Answer instance when answer exists' do
      # Setup
      db.expect(:user_questions, db)
      db.expect(:register, mock_user_question, [exam_id, user_id, question_id])
      db.expect(:answers, db)
      db.expect(:find_by_user_question,
                DBAnswer.new(answer_id, uq_id, sample_text),
                [uq_id])
      db.expect(:answers, db)
      db.expect(:create_or_update,
                DBAnswer.new(answer_id, uq_id, sample_text),
                [uq_id, sample_text])

      # Exercise
      uq = UserQuestion.new(db, exam_id, user_id, question_id)
      answer = uq.answer

      # Verify
      assert_instance_of Answer, answer
      assert_equal answer_id, answer.id
      assert_equal uq_id, answer.user_question_id
      assert_equal sample_text, answer.text
      db.verify
    end
  end

  describe Answer do
    it 'creates new answer successfully' do
      # Setup
      db.expect(:answers, db)
      db.expect(:create_or_update,
                DBAnswer.new(answer_id, uq_id, sample_text),
                [uq_id, sample_text])

      # Exercise
      answer = Answer.new(db, uq_id, sample_text)

      # Verify
      assert_equal answer_id, answer.id
      assert_equal uq_id, answer.user_question_id
      assert_equal sample_text, answer.text
      db.verify
    end

    it 'loads existing answer from database' do
      # Setup
      db.expect(:answers, db)
      db.expect(:find_by_user_question,
                DBAnswer.new(answer_id, uq_id, sample_text),
                [uq_id])

      # Exercise
      answer = Answer.new(db, uq_id)

      # Verify
      assert_equal answer_id, answer.id
      assert_equal sample_text, answer.text
      db.verify
    end

    it "raises error when answer doesn't exist" do
      # Setup
      db.expect(:answers, db)
      db.expect(:find_by_user_question, nil, [uq_id])

      # Exercise/Verify
      assert_raises(StandardError, 'Answer not found') do
        Answer.new(db, uq_id)
      end
      db.verify
    end

    it 'retrieves all reviews for the answer' do
      # Setup
      mock_reviews = [
        DBReview.new(1, 1, 5, 'Excellent'),
        DBReview.new(2, 1, 3, 'Average')
      ]
      db.expect(:answers, db)
      db.expect(:find_by_user_question,
                DBAnswer.new(answer_id, uq_id, sample_text),
                [uq_id])
      db.expect(:reviews, db)
      db.expect(:all_for_answer, mock_reviews, [uq_id])

      # Exercise
      answer = Answer.new(db, uq_id)
      reviews = answer.reviews

      # Verify
      assert_equal 2, reviews.size
      assert_equal 'Excellent', reviews.first.review
      db.verify
    end
  end

  private

  def mock_user_question
    DBUserQuestion.new(uq_id, exam_id, user_id, question_id)
  end
end
