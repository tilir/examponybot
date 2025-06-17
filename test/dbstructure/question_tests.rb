#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for question database descr
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'dbstructure'

describe Question do
  let(:db) { Minitest::Mock.new }
  let(:question_id) { 42 }
  let(:question_number) { 1 }
  let(:variant_number) { 2 }
  let(:question_text) { "What is Ruby?" }

  describe "creating new question" do
    it "persists question and initializes object" do
      # Setup mock expectations
      db.expect(:questions, db)
      db.expect(:add_question, 
                DBQuestion.new(question_id, question_number, variant_number, question_text),
                [question_number, variant_number, question_text])

      # Exercise
      question = Question.new(db, question_number, variant_number, question_text)

      # Verify
      assert_equal question_id, question.id
      assert_equal question_number, question.number
      assert_equal variant_number, question.variant
      assert_equal question_text, question.text
      db.verify
    end
  end

  describe "loading existing question" do
    it "retrieves question from database" do
      # Setup
      db.expect(:questions, db)
      db.expect(:get_question,
                DBQuestion.new(question_id, question_number, variant_number, question_text),
                [question_number, variant_number])

      # Exercise
      question = Question.new(db, question_number, variant_number)

      # Verify
      assert_equal question_id, question.id
      assert_equal question_text, question.text
      db.verify
    end
  end
end
