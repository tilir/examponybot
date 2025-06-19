#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Possible exam states with reverse mapping
#
#------------------------------------------------------------------------------

module ExamStates
  STATES = {
    stopped: 0,
    answering: 1,
    reviewing: 2,
    grading: 3
  }.freeze

  NAMES = STATES.invert.freeze

  def self.to_i(name)
    STATES.fetch(name) { raise ArgumentError, "Unknown exam state name: #{name.inspect}" }
  end

  def self.to_sym(code)
    NAMES.fetch(code) { raise ArgumentError, "Unknown exam state code: #{code.inspect}" }
  end

  def self.valid?(val)
    STATES.key?(val) || NAMES.key?(val)
  end
end
