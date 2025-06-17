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

describe "Smoke" do
  before do
    setup_test_env
    register_privuser
  end

  after do
    cleanup_test_env
  end

  it "passes workflow successfully" do
    # Test exam creation
    exam_msg = PseudoMessage.new(@prepod, @chat, '/addexam exam')
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

    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)
    p @api.text

    message = PseudoMessage.new(@student1, @chat, '/questions')
    @handler.process_message(@api, message)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/questions')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/register')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/register')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/users')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/startexam')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/register')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/users')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/answer 1 singleline from student1')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/answer 1 singleline from student2')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/answer 1 singleline from student3')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/lookup_answer 1')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/lookup_answer 2')
    @handler.process_message(@api, event)
    p @api.text

    a21 = <<~ANS
      /answer 2
      УХ
      как я
      отвечаю
    ANS
    a22 = <<~ANS
      /answer 2
      ЭХ
      как я
      отвечаю
    ANS
    a23 = <<~ANS
      /answer 2
      ЫХ
      как я
      отвечаю
    ANS

    event = PseudoMessage.new(@student1, @chat, a21)
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, a22)
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, a23)
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/lookup_answer 2')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/lookup_answer')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/lookup_question 1')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/lookup_question')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/answer 3 singleline from student1')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/answer 3 singleline from student2')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/answer 3 singleline from student3')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/startreview')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 10 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 11 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 12 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/review 12 4 like it better')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 13 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 14 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 15 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 112 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 12 -1 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, "/review 12 100 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/review')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/review 9.5')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/lookup_review 10')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/lookup_review 112')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 1 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 2 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 3 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 16 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 17 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 18 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/review 4 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/review 5 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student3, @chat, '/review 6 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/setgrades')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)
    p @api.text
  end
end
