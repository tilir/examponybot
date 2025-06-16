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

describe Question do
  let(:dbl) { Minitest::Mock.new }

  describe 'creating a new question' do
    it 'adds question to DB and sets fields' do
      dbl.expect(:add_question, 42, [1, 2, 'What is Ruby?'])

      q = Question.new(dbl, 1, 2, 'What is Ruby?')

      assert_equal 42, q.id
      assert_equal 1, q.number
      assert_equal 2, q.variant
      assert_equal 'What is Ruby?', q.text

      dbl.verify
    end
  end

  describe 'loading an existing question' do
    it 'loads question from DB by number and variant' do
      dbl.expect(:get_question, [5, 1, 2, 'Loaded text'], [1, 2])

      q = Question.new(dbl, 1, 2)

      assert_equal 5, q.id
      assert_equal 1, q.number
      assert_equal 2, q.variant
      assert_equal 'Loaded text', q.text

      dbl.verify
    end
  end

  describe 'handling missing question' do
    it 'raises if no matching question found in DB' do
      dbl.expect(:get_question, nil, [1, 2])

      assert_raises(DBLayerError) do
        Question.new(dbl, 1, 2)
      end

      dbl.verify
    end
  end
end
