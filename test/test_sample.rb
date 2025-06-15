# just to make sure testing work to create github actions pipeline
# to be extended soon

require 'minitest/autorun'
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class SampleTest < Minitest::Test
  def test_addition
    assert_equal 2, 1 + 1
  end
end

