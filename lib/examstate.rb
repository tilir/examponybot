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
    STATES.fetch(name)
  end

  def self.to_sym(code)
    NAMES.fetch(code)
  end

  def self.valid_name?(name)
    STATES.key?(name)
  end

  def self.valid_code?(code)
    NAMES.key?(code)
  end
end