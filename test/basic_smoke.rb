#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Basic smoke test using minispec helper for setup/teardown
#
#------------------------------------------------------------------------------

require 'handlers'
require 'pseudoapi'
require 'test_helper'
require 'importer'

# Configure once at the beginning (disable for clean test output)
Logger.set_verbose(false)

describe "Privileged User Registration" do
  before do
    setup_test_env
  end

  after do
    cleanup_test_env
  end

  it "successfully registers admin user" do
    # Check initial empty state
    assert @dbl.users.empty?, "User table should be empty initially"
    
    # Simulate registration command
    register_msg = PseudoMessage.new(@prepod, @chat, '/register')
    @handler.process_message(@api, register_msg)

    # Verify database state
    refute @dbl.users.empty?, "User should be added to database"
    user = User.from_db_user(@dbl, @dbl.users.get_user_by_id(167346988))
    assert user.privileged?, "User should have privileged status"
    
    # Verify bot response
    assert_equal "167346988 : Registered (privileged) as Tilir", @api.text
  end
end

describe "Exam Management Workflow" do
  before do
    setup_test_env
    register_privuser
  end

  after do
    cleanup_test_env
  end

  it "creates exam and imports questions successfully" do
    # Test exam creation
    exam_msg = PseudoMessage.new(@prepod, @chat, '/addexam Final Exam')
    @handler.process_message(@api, exam_msg)
    
    assert_equal "167346988 : Exam added", @api.text
    refute @dbl.exams.empty?, "Exam should be created in database"

    # import exam
    exam_path = File.expand_path("example_exam.txt", __dir__)
    importer = QuestionImporter.new(
      filename: exam_path,
      handler: @handler,
      api: @api,
      prepod: @prepod,
      chat: @chat
    )
    importer.import!

    # Verify imported questions
    assert_equal 3, @dbl.questions.n_questions, "Should import all 3 questions"
    assert_equal 3, @dbl.questions.n_variants, "Should support 3 variants"
  end
end
