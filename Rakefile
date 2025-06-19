require 'find'
require 'rake/testtask'
require 'rubocop/rake_task'

test_files = [
  'test/basic_smoke.rb',
  'test/basic_dblayer.rb',
  'test/userops.rb',
  'test/examstate_tests.rb',
  'test/userstate_tests.rb',
  'test/dbstructure/answer_tests.rb',
  'test/dbstructure/exam_tests.rb',
  'test/dbstructure/question_tests.rb',
  'test/dbstructure/review_tests.rb',
  'test/dbstructure/user_tests.rb',
  'test/handlers/command_tests.rb',
]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test' << 'test/dbstructure'
  t.test_files = test_files
end

# to run like:
# > bundle exec rake group['Smoke']
task :group, [:group_name] do |t, args|
  require 'find'
  
  group_name = args[:group_name]
  unless group_name
    puts "Usage: rake test:by_group['Group Name']"
    exit
  end

  puts "Searching for test group: #{group_name}"

  test_files = []
  Find.find('test') do |path|
    next unless path.end_with?('.rb') && File.file?(path)
    
    content = File.read(path)
    if content.include?(group_name)
      test_files << path 
      puts "Found in: #{path}"
    end
  end

  # puts "File content:\n#{File.read(test_files[0])}" if test_files.any?

  if test_files.empty?
    puts "Error: Test group '#{group_name}' not found".red
    exit 1
  end

  test_files.each do |file|
    puts "\nRunning tests from #{file}:"
    system("bundle exec rake test TEST=#{file} TESTOPTS=\"--verbose --name='/#{group_name}/'\"")
  end
end

RuboCop::RakeTask.new(:lint) do |task|
  task.options = ['--display-cop-names', '--extra-details']
  task.fail_on_error = false
end

RuboCop::RakeTask.new(:lint_fix) do |task|
  task.options = ['--auto-correct', '--extra-details']
  task.fail_on_error = false
end

RuboCop::RakeTask.new(:lint_fix_aggressive) do |task|
  task.options = ['--auto-correct-all', '--extra-details']
  task.fail_on_error = false
end

task :ci => [:lint, :test]

task default: :test
