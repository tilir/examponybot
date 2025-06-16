require 'rake/testtask'

test_files = [
  'test/basic_smoke.rb',
  'test/basic_dblayer.rb',
  'test/examstate_tests.rb',
  'test/userstate_tests.rb',
  'test/dbstructure/answer_tests.rb',
  'test/dbstructure/exam_tests.rb',
  'test/dbstructure/question_tests.rb',
  'test/dbstructure/review_tests.rb',
  'test/dbstructure/user_tests.rb',
]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test' << 'test/dbstructure'
  t.test_files = test_files
end

task default: :test
