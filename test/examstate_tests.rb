#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for exam states
#
#------------------------------------------------------------------------------

require_relative 'test_helper'

describe ExamStates do
  describe '.to_i' do
    it 'returns the correct integer code for a valid state name' do
      assert_equal 0, ExamStates.to_i(:stopped)
      assert_equal 1, ExamStates.to_i(:answering)
      assert_equal 2, ExamStates.to_i(:reviewing)
      assert_equal 3, ExamStates.to_i(:grading)
    end

    it 'raises ArgumentError for an unknown state name' do
      err = assert_raises(ArgumentError) { ExamStates.to_i(:unknown) }
      assert_match(/Unknown exam state name: :unknown/, err.message)
    end
  end

  describe '.to_sym' do
    it 'returns the correct symbol for a valid code' do
      assert_equal :stopped,   ExamStates.to_sym(0)
      assert_equal :answering, ExamStates.to_sym(1)
      assert_equal :reviewing, ExamStates.to_sym(2)
      assert_equal :grading,   ExamStates.to_sym(3)
    end

    it 'raises ArgumentError for an unknown state code' do
      err = assert_raises(ArgumentError) { ExamStates.to_sym(99) }
      assert_match(/Unknown exam state code: 99/, err.message)
    end
  end

  describe '.valid?' do
    it 'returns true for valid state names and codes' do
      assert ExamStates.valid?(:stopped)
      assert ExamStates.valid?(:grading)
      assert ExamStates.valid?(0)
      assert ExamStates.valid?(3)
    end

    it 'returns false for invalid names and codes' do
      refute ExamStates.valid?(:foo)
      refute ExamStates.valid?(42)
    end
  end
end
