# frozen_string_literal: true

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

describe 'Privileged User Registration' do
  before do
    setup_test_env
  end

  after do
    cleanup_test_env
  end

  it 'successfully registers admin user' do
    # Check initial empty state
    assert_empty @dbl.users, 'User table should be empty initially'

    # Simulate registration command
    register_msg = PseudoMessage.new(@prepod, @chat, '/register')
    @handler.process_message(@api, register_msg)

    # Verify bot response
    assert_includes @api.text!, 'registered as privileged'

    # Verify database state
    refute_empty @dbl.users, 'User should be added to database'
    dbuser = @dbl.users.get_user_by_id(@prepod.id)

    assert dbuser
    assert_equal :privileged, UserStates.to_sym(dbuser.privlevel), 'User should have privileged status'
  end
end

describe 'Smoke' do
  before do
    setup_test_env
    register_privuser
  end

  after do
    cleanup_test_env
  end

  it 'passes workflow successfully' do
    # initially reset state
    @api.text!

    event = PseudoMessage.new(@prepod, @chat, '/answerstat')
    @handler.process_message(@api, event)

    assert_includes @api.text!, 'ANSWERS'

    # Try to stop before exists
    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)

    assert_includes @api.text!, 'No exam to stop'

    # Test exam creation
    exam_msg = PseudoMessage.new(@prepod, @chat, '/addexam exam')
    @handler.process_message(@api, exam_msg)

    assert_includes @api.text!, 'Exam added'
    refute_empty @dbl.exams, 'Exam should be created in database'

    # import exam
    exam_path = File.expand_path('example_exam.txt', __dir__)
    importer = QuestionImporter.new(
      filename: exam_path,
      handler: @handler,
      api: @api,
      prepod: @prepod,
      chat: @chat
    )
    importer.import!

    # Verify imported questions
    assert_equal 3, @dbl.questions.n_questions, 'Should import all 3 questions'
    assert_equal 3, @dbl.questions.n_variants, 'Should support 3 variants'

    # Try stop exam which is already stopped
    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)

    assert_includes @api.text!, 'Exam already stopped'

    # Try to get question list as a student -- not available for students
    message = PseudoMessage.new(@student1, @chat, '/questions')
    @handler.process_message(@api, message)

    assert_includes @api.text!, 'Unknown command'

    # Query questions
    event = PseudoMessage.new(@prepod, @chat, '/questions')
    @handler.process_message(@api, event)
    response = @api.text!
    expected_fragments = [
      'all questions',
      *%w[1 2 3].product(%w[1 2 3]).map { |a, b| "#{a} #{b}" }
    ]

    expected_fragments.each do |fragment|
      assert_includes response, fragment
    end

    # register regular student
    event = PseudoMessage.new(@student1, @chat, '/register')
    @handler.process_message(@api, event)

    assert_includes @api.text!, 'registered as regular: student1'

    # Prepod issue help
    event = PseudoMessage.new(@prepod, @chat, '/help')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'startexam'

    # Registered student issue help
    event = PseudoMessage.new(@student1, @chat, '/help')
    @handler.process_message(@api, event)
    response = @api.text!

    refute_includes response, 'startexam'
    assert_includes response, 'lookup_question'

    # Non-registered student issue help
    event = PseudoMessage.new(@student2, @chat, '/help')
    @handler.process_message(@api, event)
    response = @api.text!

    refute_includes response, 'startexam'
    refute_includes response, 'lookup_question'
    assert_includes response, 'register'

    # register one more time
    event = PseudoMessage.new(@student1, @chat, '/register')
    @handler.process_message(@api, event)

    assert_includes @api.text!, 'already registered as student1'

    # register one more
    event = PseudoMessage.new(@student2, @chat, '/register')
    @handler.process_message(@api, event)

    assert_includes @api.text!, 'registered as regular: student2'

    assert_equal 2, @dbl.users.all_nonpriv.size
    assert_equal 3, @dbl.users.all.size

    # look up who are registered
    event = PseudoMessage.new(@prepod, @chat, '/users')
    @handler.process_message(@api, event)
    response = @api.text!

    %w[student1 student2].each do |fragment|
      assert_includes response, fragment
    end

    # puts "Before exam start:"
    # @dbl.dumpdb

    assert_equal 0, @dbl.user_questions.all.size

    # start exam: this triggers assignment of questions to all registered students
    event = PseudoMessage.new(@prepod, @chat, '/startexam')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Exam started, sending questions'
    expected_fragments = [
      *[@student1.id.to_s, @student2.id.to_s].product(%w[1 2 3]).map { |a, b| "#{a} : Question #{b}" }
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

    refute_nil uqst
    uqst = user1.nth_question(exam.id, 2)

    refute_nil uqst
    uqst = user1.nth_question(exam.id, 3)

    refute_nil uqst

    assert_equal 6, @dbl.user_questions.all.size

    # Late register (when exam started) will also get their assignments
    event = PseudoMessage.new(@student3, @chat, '/register')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'registered as regula'
    expected_fragments = [
      *[@student3.id.to_s].product(%w[1 2 3]).map { |a, b| "#{a} : Question #{b}" }
    ]

    expected_fragments.each do |fragment|
      assert_includes response, fragment
    end

    # student4 last to register and no answers
    event = PseudoMessage.new(@student4, @chat, '/register')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'registered as regula'

    # puts "After late reg:"
    # @dbl.dumpdb

    # again look up users
    event = PseudoMessage.new(@prepod, @chat, '/users')
    @handler.process_message(@api, event)
    response = @api.text!

    %w[student1 student2 student3].each do |fragment|
      assert_includes response, fragment
    end

    # first student response
    event = PseudoMessage.new(@student1, @chat, '/answer 1 singleline from student1')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, "#{@student1.id} : Answer recorded to"

    dbuser1 = @dbl.users.get_user_by_id(@student1.id)

    refute_empty @dbl.answers.user_all_answers(dbuser1.id)

    # second student response
    event = PseudoMessage.new(@student2, @chat, '/answer 1 singleline from student2')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, "#{@student2.id} : Answer recorded to"

    dbuser2 = @dbl.users.get_user_by_id(@student2.id)

    refute_empty @dbl.answers.user_all_answers(dbuser2.id)

    # third student response
    event = PseudoMessage.new(@student3, @chat, '/answer 1 singleline from student3')
    @handler.process_message(@api, event)
    response = @api.text!

    dbuser3 = @dbl.users.get_user_by_id(@student3.id)

    refute_empty @dbl.answers.user_all_answers(dbuser3.id)
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

    # second student do not response (say he don't know the answer)
    # event = PseudoMessage.new(@student2, @chat, '/answer 3 singleline from student2')
    # @handler.process_message(@api, event)
    # response = @api.text!
    # assert_includes response, "#{@student2.id} : Answer recorded to"

    # third student response again
    event = PseudoMessage.new(@student3, @chat, '/answer 3 singleline from student3')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, "#{@student3.id} : Answer recorded to"

    allanswered = @dbl.answers.all_answered_users

    assert_equal 3, allanswered.size

    # prepod looks up all answers from student1
    event = PseudoMessage.new(@prepod, @chat, "/answersof #{user1.userid}")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Answer:'

    # aggregated answer statistics
    event = PseudoMessage.new(@prepod, @chat, '/answerstat')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Answers submitted:'

    # create review assignments
    # we have 4 students, 2 have 3 answers each, 1 have 2 answers, 1 have 0 answers.
    # 2 reviewers per answer yield 16 review assignments
    event = PseudoMessage.new(@prepod, @chat, '/startreview')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Review assignment: 1'
    assert_includes response, 'Review assignment: 16'
    refute_includes response, 'Review assignment: 17'
    assert_includes response, "#{@student1.id} : You was assigned review"
    assert_includes response, "#{@student2.id} : You was assigned review"
    assert_includes response, "#{@student3.id} : You was assigned review"

    # no answers mean no review
    refute_includes response, "#{@student4.id} : You was assigned review"

    s1assignments = @dbl.reviews.get_review_assignments(@student1.id)

    refute(s1assignments.any? { |a| a[:author_telegram_id] == @student1.id })

    s2assignments = @dbl.reviews.get_review_assignments(@student2.id)

    refute(s2assignments.any? { |a| a[:author_telegram_id] == @student2.id })

    s3assignments = @dbl.reviews.get_review_assignments(@student3.id)

    refute(s3assignments.any? { |a| a[:author_telegram_id] == @student3.id })

    total = s1assignments.size + s2assignments.size + s3assignments.size

    # every answer gone to N_REVIEWERS
    assert_equal total, @dbl.answers.all.size * N_REVIEWERS

    # puts "After review assignment #{total}"
    # @dbl.dumpdb

    # student reviews proper assignment (urid correct)
    review_id = s1assignments.dig(0, :assignment)&.id
    event = PseudoMessage.new(@student1, @chat, "/review #{review_id} 2 don't like it")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, "#{@student1.id} : Review assignment"
    assert_includes response, 'recorded/updated'
    assert_includes response, "#{@student1.id} : You sent"

    assert_equal 1, @dbl.reviews.tguser_reviews(@student1.id).size

    # student reviews improper assignment (urid incorrect, 11000 is too large)
    event = PseudoMessage.new(@student1, @chat, "/review 11000 2 don't like it")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'is not your review assignment'

    # all other proper ones
    ncorr = 1
    s1assignments.each_with_index do |assignment, _index|
      review_id = assignment[:assignment].id
      # first check was manual
      next if review_id == s1assignments.dig(0, :assignment)&.id

      event = PseudoMessage.new(@student1, @chat, "/review #{review_id} 2 don't like it")
      @handler.process_message(@api, event)
      response = @api.text!
      ncorr += 1

      assert_includes response, "#{@student1.id} : You sent #{ncorr} out of #{s1assignments.size} required reviews"
    end

    # try to set -1
    review_id = s1assignments.dig(0, :assignment)&.id
    event = PseudoMessage.new(@student1, @chat, "/review #{review_id} -1 don't like it")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Grade shall be 1 .. 10'

    # try to set 100
    review_id = s1assignments.dig(0, :assignment)&.id
    event = PseudoMessage.new(@student1, @chat, "/review #{review_id} 100 really like it")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Grade shall be 1 .. 10'

    # try void command
    event = PseudoMessage.new(@student1, @chat, '/review')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'You need to specify review number, grade and review text'

    # try review assigment 9.5
    event = PseudoMessage.new(@student1, @chat, '/review 9.5')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'You need to specify review number, grade and review text'

    # lookup
    review_id = s1assignments.dig(0, :assignment)&.id
    event = PseudoMessage.new(@student1, @chat, "/lookup_review #{review_id}")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, "Grade: 2. Text: don't like it"

    # incorrect lookup
    event = PseudoMessage.new(@student1, @chat, '/lookup_review 100500')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'is not your review assignment'

    # student 2
    ncorr = 0
    s2assignments.each_with_index do |assignment, _index|
      review_id = assignment[:assignment].id
      event = PseudoMessage.new(@student2, @chat, "/review #{review_id} 10 like it")
      @handler.process_message(@api, event)
      response = @api.text!
      ncorr += 1

      assert_includes response, "#{@student2.id} : You sent #{ncorr} out of #{s2assignments.size} required reviews"
    end

    # student 3: except one
    ncorr = 0
    s3assignments.each_with_index do |assignment, index|
      next if index.zero?

      review_id = assignment[:assignment].id
      event = PseudoMessage.new(@student3, @chat, "/review #{review_id} 10 like it")
      @handler.process_message(@api, event)
      response = @api.text!
      ncorr += 1

      assert_includes response, "#{@student3.id} : You sent #{ncorr} out of #{s3assignments.size} required reviews"
    end

    # uberrazdolb tries to register
    event = PseudoMessage.new(@student5, @chat, '/register')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Exam not accepting registers now'

    # prepod looks up all reviews from student1
    event = PseudoMessage.new(@prepod, @chat, "/reviewsof #{user1.userid}")
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Review:'

    event = PseudoMessage.new(@prepod, @chat, '/reviewstat')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Reviews submitted:'

    # time to set grades
    event = PseudoMessage.new(@prepod, @chat, '/setgrades')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, "#{@student1.id} : Reviews for your question"
    assert_includes response, "#{@student2.id} : Reviews for your question"
    assert_includes response, "#{@student3.id} : You haven't done your reviewing due"
    assert_includes response, "#{@student1.id} : Your approx grade is"
    assert_includes response, "#{@student2.id} : Your approx grade is"

    # finish
    event = PseudoMessage.new(@prepod, @chat, '/stopexam')
    @handler.process_message(@api, event)
    response = @api.text!

    assert_includes response, 'Exam stopped'
  end
end
