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

describe "UserQuestion and Answer" do
  let(:dbl)         { Minitest::Mock.new }
  let(:examid)      { 1 }
  let(:userid)      { 2 }
  let(:questionid)  { 3 }
  let(:uqid)        { 42 }
  let(:answer_id)   { 99 }

  describe UserQuestion do
    it "registers user question correctly" do
      dbl.expect :register_question, uqid, [examid, userid, questionid]

      uq = UserQuestion.new(dbl, examid, userid, questionid)

      assert_equal uqid, uq.id
      assert_equal examid, uq.examid
      assert_equal userid, uq.userid
      assert_equal questionid, uq.questionid
      dbl.verify
    end

    it "returns nil when no answer exists" do
      dbl.expect :register_question, uqid, [examid, userid, questionid]
      dbl.expect :uqid_to_answer, nil, [uqid]

      uq = UserQuestion.new(dbl, examid, userid, questionid)

      assert_nil uq.to_answer
      dbl.verify
    end

    it "returns an Answer when answer exists" do
      dbl.expect :register_question, uqid, [examid, userid, questionid]
      dbl.expect :uqid_to_answer, [answer_id, uqid, "Sample answer"], [uqid]
      dbl.expect :uqid_to_answer, [answer_id, uqid, "Sample answer"], [uqid]

      uq = UserQuestion.new(dbl, examid, userid, questionid)

      answer = uq.to_answer
      assert_instance_of Answer, answer
      assert_equal answer_id, answer.id
      assert_equal uqid, answer.uqid
      assert_equal "Sample answer", answer.text
      dbl.verify
    end

    it "returns a Question from DB" do
      dbl.expect :record_answer, answer_id, [uqid, "Text"]
      dbl.expect :register_question, uqid, [examid, userid, questionid]
      dbl.expect :awid_to_userquestion, [examid, userid, questionid], [answer_id]
      dbl.expect :add_question, questionid, [1, 2, "Sample?"]
      dbl.expect :uqid_to_question, [dbl, 1, 2, "Sample?"], [uqid]

      answer = Answer.new(dbl, uqid, "Text")
      q = answer.to_question

      assert_instance_of Question, q
      dbl.verify
    end
  end

  describe Answer do
    it "creates and stores new answer" do
      dbl.expect :record_answer, answer_id, [uqid, "Text"]

      answer = Answer.new(dbl, uqid, "Text")
      assert_equal answer_id, answer.id
      assert_equal uqid, answer.uqid
      assert_equal "Text", answer.text
      dbl.verify
    end

    it "loads answer from DB when no text provided" do
      dbl.expect :uqid_to_answer, [answer_id, uqid, "Loaded answer"], [uqid]

      answer = Answer.new(dbl, uqid)
      assert_equal answer_id, answer.id
      assert_equal uqid, answer.uqid
      assert_equal "Loaded answer", answer.text
      dbl.verify
    end

    it "raises when no such answer in DB" do
      dbl.expect :uqid_to_answer, nil, [uqid]

      assert_raises(DBLayerError) do
        Answer.new(dbl, uqid)
      end

      dbl.verify
    end

    it "returns reviews via all_reviews" do
      dbl.expect :uqid_to_answer, [answer_id, uqid, "Loaded answer"], [uqid]
      dbl.expect :allreviews, [1, 2], [uqid]

      answer = Answer.new(dbl, uqid)
      reviews = answer.all_reviews
      assert_equal [1, 2], reviews
      dbl.verify
    end
  end
end
