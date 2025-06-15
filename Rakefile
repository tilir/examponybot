require 'rake/testtask'

test_files = [
  'test/test_sample.rb',
]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = test_files
end

task default: :test
