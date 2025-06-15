
require 'minitest/autorun'
require 'minitest/reporters'
require 'handlers'
require 'pseudoapi'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

describe "PonyBot" do
  DB_PATH = 'test.db'

  after do
    FileUtils.rm_f(DB_PATH)
  end

  it "basic user registers correct " do
    handler = Handler.new(DB_PATH)
    api = PseudoApi.new
    prepod = PseudoUser.new(167_346_988, 'Tilir')
    chat = PseudoChat.new(1)
    event = PseudoMessage.new(prepod, chat, '/register')
    handler.process_message(api, event)
    p api.text
    assert_equal(api.text, "167346988 : Registered (priviledged) as Tilir")
  end
end

