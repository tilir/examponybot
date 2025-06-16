require 'rake/testtask'

test_files = [
  'test/basic_smoke.rb',
  'test/examstate_tests.rb',
  'test/userstate_tests.rb',
  'test/user_tests.rb',
  'test/question_tests.rb',
  'test/exam_tests.rb',
  'test/answer_tests.rb',
  'test/review_tests.rb',
]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = test_files
end

task default: :test
