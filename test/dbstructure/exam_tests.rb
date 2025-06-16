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
require 'dbstructure'

describe Exam do
  before do
    @dbl = Minitest::Mock.new
    @exam_data = [42, ExamStates.to_i(:stopped), "Midterm Exam"]
    @dbl.expect(:add_exam, @exam_data, ["Midterm Exam"])
    @exam = Exam.new(@dbl, "Midterm Exam")
  end

  after do
    @dbl.verify
  end

  it "initializes exam with correct attributes" do
    assert_equal 42, @exam.id
    assert_equal "Midterm Exam", @exam.name
    assert_equal :stopped, @exam.state
  end

  it "changes state correctly" do    
    @dbl.expect(:set_exam_state, nil, [@exam.name, ExamStates.to_i(:answering)])
    @exam.set_state(:answering)
    assert_equal :answering, @exam.state
  end

  it "raises error on invalid state" do
    assert_raises(ArgumentError) { @exam.set_state(:nonexistent_state) }
  end

  it "has correct string representation" do
    expected_str = <<~EXAM
      Exam: 42
      \tName: Midterm Exam
      \tState: stopped (0)
    EXAM
    assert_equal expected_str, @exam.to_s
  end
end
