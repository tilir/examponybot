#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for command handler
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'ostruct'
require 'handlers'

# Configure once at the beginning (disable for clean test output)
Logger.set_verbose(true)

describe Handler::Command do
  let(:dbname) { ':memory:' }
  let(:dbl) { DBLayer.new(dbname) }
  let(:tguser) { OpenStruct.new(id: 123, username: 'testuser') }

  before do
    dbl.clear_all! if dbl.respond_to?(:clear_all!)
  end

  it 'registers the first user as privileged' do
    assert dbl.users.users_empty?
    mock_api = Minitest::Mock.new    
    cmd = Handler::Command.new(mock_api, tguser, dbl)
    mock_api.expect(:send_message, nil) do |h|
      # puts ""
      # puts "+++ #{h[:text]}"
      h[:chat_id] == tguser.id && h[:text].include?('Test Name')
    end

    cmd.register('Test Name')

    dbuser = dbl.users.get_user_by_id(tguser.id)
    assert_equal :privileged, UserStates.to_sym(dbuser.privlevel)
    assert_equal 'Test Name', dbuser.username
    mock_api.verify
  end

  it 'registers next users as regular' do
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == tguser.id && h[:text].include?('First')
    end
    Handler::Command.new(mock_api, tguser, dbl).register('First')

    tguser2 = OpenStruct.new(id: 456, username: 'second')

    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == tguser2.id && h[:text].include?('XXX')
    end
    Handler::Command.new(mock_api, tguser2, dbl).register('XXX')

    dbuser = dbl.users.get_user_by_id(tguser2.id)
    assert_equal :regular, UserStates.to_sym(dbuser.privlevel)
    mock_api.verify
  end

  it 'uses username if name is not given' do
    mock_api = Minitest::Mock.new

    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == 123 && h[:text].include?('testuser')
    end

    cmd = Handler::Command.new(mock_api, tguser, dbl)
    cmd.register

    assert_equal 'testuser', dbl.users.get_user_by_id(tguser.id).username
    mock_api.verify
  end

  it 'uses userid as fallback name' do
    tguser_no_username = OpenStruct.new(id: 123, username: nil)
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == 123 && h[:text].include?('123')
    end

    cmd = Handler::Command.new(mock_api, tguser_no_username, dbl)
    cmd.register
    assert_equal '123', dbl.users.get_user_by_id(tguser.id).username
    mock_api.verify
  end

  it 'assigns questions if exam exists and user not in all_nonpriv' do
    exam = Exam.new(dbl, 'exam')
    exam.set_state(:answering)
    user = dbl.users.add_user(123, 1, 'user')

    dbl.questions.add_question(1, 1, 'Q1')
    dbl.questions.add_question(2, 1, 'Q2')
    dbl.questions.add_question(1, 2, 'Q3')
    dbl.questions.add_question(2, 2, 'Q4')

    assert_equal 2, dbl.questions.n_questions
    assert_equal 2, dbl.questions.n_variants
    assert dbl.exams.any? 
    assert dbl.users.all_nonpriv.any? { |u| u.userid == user.userid }

    exam = Exam.new(dbl, 'exam')
    refute exam.state == :stopped

    mock_api = Minitest::Mock.new
    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == 123 && h[:text].include?('name changed')
    end
    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == 123 && h[:text].include?('Question 1, variant')
    end
    mock_api.expect(:send_message, nil) do |h|
      h[:chat_id] == 123 && h[:text].include?('Question 2, variant')
    end

    cmd = Handler::Command.new(mock_api, tguser, dbl)
    cmd.register
  end
end

