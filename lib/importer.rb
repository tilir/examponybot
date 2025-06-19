#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Exam importer
#
#------------------------------------------------------------------------------

require_relative 'handlers'
require_relative 'pseudoapi'
require_relative 'logger'

# Configure once at the beginning (disable for clean test output)
Logger.set_verbose(false)

class QuestionImporter
  def initialize(filename:, handler:, api:, prepod:, chat:)
    @filename = filename
    @handler = handler
    @api = api
    @prepod = prepod
    @chat = chat
    @verbose = false
  end

  def import!
    grouped_questions = parse_file(@filename)

    raise 'Error: no question group found' if grouped_questions.empty? || grouped_questions.all?(&:empty?)

    question_counts = grouped_questions.map(&:size).uniq
    raise "Error counts differ: #{question_counts.join(', ')}" if question_counts.size > 1

    grouped_questions.each_with_index do |questions, grp_index|
      group_id = grp_index + 1
      Logger.print "Group #{group_id} (#{questions.size} questions)" if @verbose

      questions.each_with_index do |question_text, question_index|
        question_id = question_index + 1
        send_question(group_id, question_id, question_text)
      end
    end
  end

  private

  def parse_file(path)
    lines = File.read(path).lines.map(&:rstrip)

    groups = []
    current_group = []
    in_group = false

    lines.each do |line|
      if line.strip == '==='
        groups << current_group unless current_group.empty?
        current_group = []
        in_group = true
      elsif in_group
        current_group << line
      end
    end
    groups << current_group unless current_group.empty?

    # split group to questions
    groups.map do |group_lines|
      group_lines.join("\n").split(/^---$/).map(&:strip).reject(&:empty?)
    end
  end

  def send_question(exam_id, question_id, text)
    command = "/addquestion #{exam_id} #{question_id}"
    full_text = "#{command}\n#{text}"

    event = PseudoMessage.new(@prepod, @chat, full_text)
    @handler.process_message(@api, event)

    Logger.print "Q#{exam_id}.#{question_id} added: #{@api.text}" if @verbose
  end
end
