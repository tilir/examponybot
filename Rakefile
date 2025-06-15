require 'rake/testtask'

test_files = [
  'test/basic_smoke.rb',
]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = test_files
end

task default: :test
