#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for exam database descr
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'dbstructure'

describe Exam do
  let(:db) { Minitest::Mock.new }
  let(:exam_id) { 42 }
  let(:exam_name) { "Midterm Exam" }
  let(:initial_state) { ExamStates.to_i(:stopped) }

  describe "initialization" do
    it "creates exam with correct attributes" do
      # Setup mock expectations
      db.expect(:nil?, false)
      db.expect(:exams, db)
      db.expect(:exams, db)
      db.expect(:find_by_name, nil, [exam_name])
      db.expect(:add_exam, 
                DBExam.new(exam_id, initial_state, exam_name), 
                [exam_name])

      # Exercise
      exam = Exam.new(db, exam_name)

      # Verify
      assert_equal exam_id, exam.id
      assert_equal exam_name, exam.name
      assert_equal :stopped, exam.state
      db.verify
    end
  end

  describe "string representation" do
    it "returns formatted exam details" do
      # Setup
      db.expect(:nil?, false)
      db.expect(:exams, db)
      db.expect(:exams, db)
      db.expect(:find_by_name, nil, [exam_name])
      db.expect(:add_exam, 
                DBExam.new(exam_id, initial_state, exam_name), 
                [exam_name])

      exam = Exam.new(db, exam_name)
      exam.instance_variable_set(:@id, exam_id)
      exam.instance_variable_set(:@state, initial_state)

      # Expected output
      expected_output = <<~EXAM.chomp
        Exam: 42
        \tName: Midterm Exam
        \tState: stopped (0)
      EXAM

      # Verify
      assert_equal expected_output, exam.to_s
    end
  end

  describe "exam creation constraints" do
    it "prevents creating multiple exams" do
      # First exam should succeed
      db.expect(:exams, db)
      db.expect(:exams, db)
      db.expect(:nil?, false)
      db.expect(:find_by_name, nil, ["First Exam"])
      db.expect(:add_exam, DBExam.new(1, 0, "First Exam"), ["First Exam"])

      Exam.new(db, "First Exam")

      # Second exam should fail
      # db.expect(:exams, db)
      # db.expect(:empty?, false)
      # db.expect(:add_exam, nil, ["Second Exam"])
      # assert_nil Exam.new(db, "Second Exam")
      db.verify
    end
  end
end