# frozen_string_literal: true

#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for review database descr
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'dbstructure'

describe 'Review System' do
  let(:db) { Minitest::Mock.new }
  let(:reviewer_id) { 1 }
  let(:user_question_id) { 42 }
  let(:review_assignment_id) { 100 }
  let(:review_id) { 99 }
  let(:grade) { 5 }
  let(:review_text) { 'Excellent work' }

  describe UserReview do
    it 'creates new review assignment successfully' do
      # Setup mock
      db.expect(:reviews, db)
      db.expect(:assign_reviewer,
                DBUserReview.new(review_assignment_id, reviewer_id, user_question_id),
                [reviewer_id, user_question_id])

      # Exercise
      assignment = UserReview.new(db, reviewer_id, user_question_id)

      # Verify
      assert_equal review_assignment_id, assignment.id
      assert_equal reviewer_id, assignment.reviewer_id
      assert_equal user_question_id, assignment.user_question_id
      db.verify
    end

    it 'generates proper string representation' do
      # Setup
      db.expect(:reviews, db)
      db.expect(:assign_reviewer,
                DBUserReview.new(review_assignment_id, reviewer_id, user_question_id),
                [reviewer_id, user_question_id])

      # Exercise
      assignment = UserReview.new(db, reviewer_id, user_question_id)
      output = assignment.to_s

      # Verify
      assert_includes output, "Reviewer: #{reviewer_id}"
      assert_includes output, "UserQuestion: #{user_question_id}"
      db.verify
    end
  end

  describe Review do
    describe 'creating new review' do
      it 'records review with grade and feedback' do
        # Setup
        db.expect(:reviews, db)
        db.expect(:submit,
                  DBReview.new(review_id, review_assignment_id, grade, review_text),
                  [review_assignment_id, grade, review_text])

        # Exercise
        review = Review.new(db, review_assignment_id, grade, review_text)

        # Verify
        assert_equal review_id, review.id
        assert_equal grade, review.grade
        assert_equal review_text, review.review
        db.verify
      end
    end

    describe 'loading existing review' do
      it 'retrieves review details from database' do
        # Setup
        db.expect(:reviews, db)
        db.expect(:find_by_assignment,
                  DBReview.new(review_id, review_assignment_id, grade, review_text),
                  [review_assignment_id])

        # Exercise
        review = Review.new(db, review_assignment_id)

        # Verify
        assert_equal grade, review.grade
        assert_equal review_text, review.review
        db.verify
      end

      it 'raises error when review not found' do
        # Setup
        db.expect(:reviews, db)
        db.expect(:find_by_assignment, nil, [review_assignment_id])

        # Exercise/Verify
        assert_raises('Review not found') do
          Review.new(db, review_assignment_id)
        end
        db.verify
      end
    end

    it 'generates correct string representation' do
      # Setup
      db.expect(:reviews, db)
      db.expect(:submit,
                DBReview.new(review_id, review_assignment_id, grade, review_text),
                [review_assignment_id, grade, review_text])

      # Exercise
      review = Review.new(db, review_assignment_id, grade, review_text)
      output = review.to_s

      # Verify
      assert_includes output, "Grade: #{grade}"
      assert_includes output, "Text: #{review_text}"
      db.verify
    end
  end
end
