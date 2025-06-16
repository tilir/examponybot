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

describe "UserReview and Review" do
  let(:dbl) { Minitest::Mock.new }
  let(:userid) { 1 }
  let(:uqid) { 42 }
  let(:revid) { 100 }
  let(:review_id) { 99 }

  describe UserReview do
    it "creates a new review assignment" do
      dbl.expect :create_review_assignment, 55, [userid, uqid]
      ur = UserReview.new(dbl, userid, uqid)

      assert_equal 55, ur.id
      assert_equal userid, ur.userid
      assert_equal uqid, ur.userquestionid
      dbl.verify
    end

    it "prints string representation" do
      dbl.expect :create_review_assignment, 55, [userid, uqid]
      ur = UserReview.new(dbl, userid, uqid)

      str = ur.to_s
      assert_includes str, "UserId: 1"
      assert_includes str, "UserQuestionId: 42"
      dbl.verify
    end
  end

  describe Review do
    it "records a new review when grade and text are given" do
      dbl.expect :record_review, review_id, [revid, 5, "Well done"]
      review = Review.new(dbl, revid, 5, "Well done")

      assert_equal review_id, review.id
      assert_equal 5, review.grade
      assert_equal "Well done", review.text
      dbl.verify
    end

    it "loads a review from DB if no grade/text provided" do
      dbl.expect :query_review, [review_id, revid, 4, "Nice"], [revid]
      review = Review.new(dbl, revid)

      assert_equal 4, review.grade
      assert_equal "Nice", review.text
      assert_equal review_id, review.id
      dbl.verify
    end

    it "raises error if review not found in DB" do
      dbl.expect :query_review, nil, [revid]
      assert_raises(DBLayerError) { Review.new(dbl, revid) }
      dbl.verify
    end

    it "generates string representation" do
      dbl.expect :record_review, review_id, [revid, 3, "OK"]
      r = Review.new(dbl, revid, 3, "OK")

      str = r.to_s
      assert_includes str, "Grade: 3"
      assert_includes str, "Text: OK"
      dbl.verify
    end
  end
end
