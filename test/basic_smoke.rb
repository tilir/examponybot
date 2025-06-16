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

# set to true for lots of debug output
Logger.set_verbose(false)

describe "PonyBot register privileged" do
  before { setup_test_env }
  after { cleanup_test_env }

  it "basic privileged user registers correct " do
    assert @dbl.users_empty?, "Expected user DB to be empty before registration"
    register_privuser
    refute @dbl.users_empty?, "Expected user DB to contain the registered user"
    assert_empty @dbl.all_nonpriv_users, "No non-priv-users expected at this point"
    assert_equal "167346988 : Registered (privileged) as Tilir", @api.text
  end
end

describe "PonyBot create start and stop exam" do
  before do
    setup_test_env
    register_privuser
  end

  after do
    cleanup_test_env
  end

  it "adding exam" do
    event = PseudoMessage.new(@prepod, @chat, '/addexam')
    @handler.process_message(@api, event)
    assert_equal "167346988 : Exam added", @api.text
    refute @dbl.exams_empty?

    exam_path = File.expand_path("example_exam.txt", __dir__)

    importer = QuestionImporter.new(
      filename: exam_path,
      handler: @handler,
      api: @api,
      prepod: @prepod,
      chat: @chat
    )
    importer.import!

    assert_equal 3, @dbl.n_questions
    assert_equal 3, @dbl.n_variants
  end
end


