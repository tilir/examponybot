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

    # Verify bot response
    assert_includes @api.text!, "registered as privileged"

    # Verify database state
    refute @dbl.users.empty?, "User should be added to database"
    dbuser = @dbl.users.get_user_by_id(@prepod.id)
    assert dbuser
    assert_equal :privileged, UserStates.to_sym(dbuser.privlevel), "User should have privileged status"
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
    # initially reset state
    @api.text!

    # Try to stop before exists
    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)
    assert_includes @api.text!, "No exam to stop"

    # Test exam creation
    exam_msg = PseudoMessage.new(@prepod, @chat, '/addexam exam')
    @handler.process_message(@api, exam_msg)
    
    assert_includes @api.text!, "Exam added"
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

    # Try stop exam which is already stopped
    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)
    assert_includes @api.text!, "Exam already stopped"

    # Try to get question list as a student -- not available for students
    message = PseudoMessage.new(@student1, @chat, '/questions')
    @handler.process_message(@api, message)
    assert_includes @api.text!, "Unknown command"

    # Query questions
    event = PseudoMessage.new(@prepod, @chat, '/questions')
    @handler.process_message(@api, event)
    response = @api.text!
    expected_fragments = [
      "all questions",
      *["1", "2", "3"].product(["1", "2", "3"]).map { |a,b| "#{a} #{b}" }
    ]

    expected_fragments.each do |fragment|
      assert_includes response, fragment
    end

    # register regular student
    event = PseudoMessage.new(@student1, @chat, '/register')
    @handler.process_message(@api, event)
    assert_includes @api.text!, "registered as regular: student1"

    # register one more time
    event = PseudoMessage.new(@student1, @chat, '/register')
    @handler.process_message(@api, event)
    assert_includes @api.text!, "already registered as student1"

    # register one more
    event = PseudoMessage.new(@student2, @chat, '/register')
    @handler.process_message(@api, event)
    assert_includes @api.text!, "registered as regular: student2"

    assert_equal 2, @dbl.users.all_nonpriv.size
    assert_equal 3, @dbl.users.all.size

    # look up who are registered
    event = PseudoMessage.new(@prepod, @chat, '/users')
    @handler.process_message(@api, event)
    response = @api.text!
    ["student1", "student2"].each do |fragment|
      assert_includes response, fragment
    end

    # puts "Before exam start:"
    # @dbl.dumpdb

    assert_equal 0, @dbl.user_questions.all.size

    # start exam: this triggers assignment of questions to all registered students
    event = PseudoMessage.new(@prepod, @chat, '/startexam')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "Exam started, sending questions"
    expected_fragments = [
      *[@student1.id.to_s, @student2.id.to_s].product(["1", "2", "3"]).map { |a,b| "#{a} : Question #{b}" }
    ]

    expected_fragments.each do |fragment|
      assert_includes response, fragment
    end

    # Ensure uqid's are correct
    exam = Exam.new(@dbl, 'exam')
    assert_equal :answering, exam.state

    dbuser1 = @dbl.users.get_user_by_id(@student1.id)
    user1 = User.from_db_user(@dbl, dbuser1)
    uqst = user1.nth_question(exam.id, 1)
    refute uqst.nil?
    uqst = user1.nth_question(exam.id, 2)
    refute uqst.nil?
    uqst = user1.nth_question(exam.id, 3)
    refute uqst.nil?

    assert_equal 6, @dbl.user_questions.all.size

    # Late register (when exam started) will also get their assignments
    event = PseudoMessage.new(@student3, @chat, '/register')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "registered as regula"
    expected_fragments = [
      *[@student3.id.to_s].product(["1", "2", "3"]).map { |a,b| "#{a} : Question #{b}" }
    ]

    expected_fragments.each do |fragment|
      assert_includes response, fragment
    end

    # puts "After late reg:"
    # @dbl.dumpdb

    # again look up users
    event = PseudoMessage.new(@prepod, @chat, '/users')
    @handler.process_message(@api, event)
    response = @api.text!
    ["student1", "student2", "student3"].each do |fragment|
      assert_includes response, fragment
    end

    # first student response
    event = PseudoMessage.new(@student1, @chat, '/answer 1 singleline from student1')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student1.id} : Answer recorded to"

    dbuser1 = @dbl.users.get_user_by_id(@student1.id)
    refute @dbl.answers.user_all_answers(dbuser1.id).empty?

    # second student response
    event = PseudoMessage.new(@student2, @chat, '/answer 1 singleline from student2')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student2.id} : Answer recorded to"

    dbuser2 = @dbl.users.get_user_by_id(@student2.id)
    refute @dbl.answers.user_all_answers(dbuser2.id).empty?

    # third student response
    event = PseudoMessage.new(@student3, @chat, '/answer 1 singleline from student3')
    @handler.process_message(@api, event)
    response = @api.text!

    dbuser3 = @dbl.users.get_user_by_id(@student3.id)
    refute @dbl.answers.user_all_answers(dbuser3.id).empty?
    assert_includes response, "#{@student3.id} : Answer recorded to"

    # student lookup for reponse
    event = PseudoMessage.new(@student3, @chat, '/lookup_answer 1')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : singleline from student3"

    # student lookup for non-existent reponse
    event = PseudoMessage.new(@student3, @chat, '/lookup_answer 2')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : You haven't answered yet"

    # first student response again
    a21 = <<~ANS
      /answer 2
      УХ
      как я
      отвечаю
    ANS

    event = PseudoMessage.new(@student1, @chat, a21)
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student1.id} : Answer recorded to"

    a22 = <<~ANS
      /answer 2
      ЭХ
      как я
      отвечаю
    ANS

    event = PseudoMessage.new(@student2, @chat, a22)
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student2.id} : Answer recorded to"

    a23 = <<~ANS
      /answer 2
      ЫХ
      как я
      отвечаю
    ANS

    event = PseudoMessage.new(@student3, @chat, a23)
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : Answer recorded to"

    # student lookup for now existing reponse
    event = PseudoMessage.new(@student3, @chat, '/lookup_answer 2')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : ЫХ"

    # student lookup for answer without number
    event = PseudoMessage.new(@student3, @chat, '/lookup_answer')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : Question have incorrect number 0. Allowed range: [1 .. 3]"

    # student lookup for question (assigned randomly so just smoke here)
    event = PseudoMessage.new(@student3, @chat, '/lookup_question 1')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : "

    # student lookup for question without number
    event = PseudoMessage.new(@student3, @chat, '/lookup_question')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : Question have incorrect number 0. Allowed range: [1 .. 3]"

    # first student response again
    event = PseudoMessage.new(@student1, @chat, '/answer 3 singleline from student1')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student1.id} : Answer recorded to"

    # second student response again
    event = PseudoMessage.new(@student2, @chat, '/answer 3 singleline from student2')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student2.id} : Answer recorded to"

    # third student response again
    event = PseudoMessage.new(@student3, @chat, '/answer 3 singleline from student3')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "#{@student3.id} : Answer recorded to"

    # create review assignments
    # we have 3 students, 3 answers each, 2 reviewers per answer yield 18 review assignments
    event = PseudoMessage.new(@prepod, @chat, '/startreview')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "Review assignment: 1"
    assert_includes response, "Review assignment: 18"
    refute_includes response, "Review assignment: 19"

=begin
    event = PseudoMessage.new(@student1, @chat, "/review 10 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 11 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 12 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/review 12 4 like it better')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 13 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 14 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 15 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 112 2 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 12 -1 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, "/review 12 100 don't like it")
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, '/review')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student1, @chat, '/review 9.5')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, '/lookup_review 10')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student1, @chat, '/lookup_review 112')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student2, @chat, '/review 1 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student2, @chat, '/review 2 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student2, @chat, '/review 3 10 like it')
    @handler.process_message(@api, event)
    p @api.text

    event = PseudoMessage.new(@student2, @chat, '/review 16 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student2, @chat, '/review 17 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student2, @chat, '/review 18 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student3, @chat, '/review 4 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student3, @chat, '/review 5 10 like it')
    @handler.process_message(@api, event)
    p @api.text!

    event = PseudoMessage.new(@student3, @chat, '/review 6 10 like it')
    @handler.process_message(@api, event)
    p @api.text!
=end

    # time to set grades
    event = PseudoMessage.new(@prepod, @chat, '/setgrades')
    @handler.process_message(@api, event)
    p @api.text!

    # finish
    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)
    response = @api.text!
    assert_includes response, "Exam stopped"
  end
end
