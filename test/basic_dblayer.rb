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
require 'sqlite3'
require 'dblayer'

describe DBLayer do
  before do
    @dbl = DBLayer.new(':memory:')
  end

  after do
    @dbl.close
  end

  describe '#add_user and #get_user_by_id' do
    it 'adds and retrieves a user' do
      id = @dbl.add_user('tg1', 1, 'Alice')
      assert id.is_a?(Integer)

      user = @dbl.get_user_by_id('tg1')
      assert_equal 'tg1', user[1]
      assert_equal 'Alice', user[2]
    end

    it 'updates an existing user' do
      id1 = @dbl.add_user('tg1', 1, 'Alice')
      id2 = @dbl.add_user('tg1', 2, 'AliceUpdated')

      assert_equal id1, id2
      user = @dbl.get_user_by_id('tg1')
      assert_equal 'AliceUpdated', user[2]
    end
  end

  describe '#users_empty? and #all_users' do
    it 'returns true when no users' do
      assert_equal true, @dbl.users_empty?
    end

    it 'returns all users after insert' do
      @dbl.add_user('tg2', 2, 'Bob')
      users = @dbl.all_users
      assert_equal 1, users.length
      assert_equal 'tg2', users.first.userid
    end
  end

  describe '#add_question and #get_question' do
    it 'adds and retrieves a question' do
      @dbl.add_question(1, 1, 'Q?')
      q = @dbl.get_question(1, 1)
      assert_equal 'Q?', q[3]
    end

    it 'updates an existing question' do
      @dbl.add_question(1, 1, 'Old')
      @dbl.add_question(1, 1, 'New')
      q = @dbl.get_question(1, 1)
      assert_equal 'New', q[3]
    end
  end

  describe '#add_exam and #exams_empty?' do
    it 'adds an exam and prevents duplicates' do
      ex = @dbl.add_exam('Exam A')
      refute_nil ex

      ex2 = @dbl.add_exam('Exam A')
      assert_equal ex[0], ex2[0]
    end

    it 'returns nil if second exam added' do
      @dbl.add_exam('A')
      assert_nil @dbl.add_exam('B')
    end
  end

  describe '#register_question and #user_nth_question' do
    it 'registers and retrieves a question for user' do
      uid = @dbl.add_user('u', 1, 'U')
      qid = @dbl.add_question(1, 1, 'Q')
      exam = @dbl.add_exam('E')
      @dbl.register_question(exam[0], uid, qid)

      result = @dbl.user_nth_question(exam[0], uid, 1)
      assert_equal exam[0], result[0]
      assert_equal uid, result[1]
    end
  end

  describe '#record_answer and #user_all_answers' do
    it 'records and retrieves answers for a user' do
      uid = @dbl.add_user('u1', 1, 'U1')
      qid = @dbl.add_question(1, 1, 'Q')
      ex = @dbl.add_exam('E1')
      uqid = @dbl.register_question(ex[0], uid, qid)

      aid = @dbl.record_answer(uqid, '42')
      assert aid.is_a?(Integer)

      answers = @dbl.user_all_answers(uid)
      assert_equal uqid, answers.first.uqid
    end
  end

  describe '#create_review_assignment, #record_review, #nreviews, #query_review' do
    it 'assigns and stores a review' do
      uid = @dbl.add_user('rev', 1, 'Reviewer')
      qid = @dbl.add_question(1, 1, 'Q')
      ex = @dbl.add_exam('E')
      uqid = @dbl.register_question(ex[0], uid, qid)

      rid = @dbl.create_review_assignment(uid, uqid)
      assert rid.is_a?(Integer)

      @dbl.record_review(rid, 5, 'Good')
      assert_equal 1, @dbl.nreviews(uid)

      r = @dbl.query_review(rid)
      assert_equal 5, r[2]
    end
  end

  describe '#allreviews' do
    it 'returns all reviews for a user-question' do
      uid = @dbl.add_user('X', 1, 'X')
      qid = @dbl.add_question(1, 1, 'Q')
      ex = @dbl.add_exam('E')
      uqid = @dbl.register_question(ex[0], uid, qid)
      rid = @dbl.create_review_assignment(uid, uqid)
      @dbl.record_review(rid, 10, 'Fine')

      reviews = @dbl.allreviews(uqid)
      assert_equal 10, reviews.first.instance_variable_get(:@grade)
    end
  end
end
