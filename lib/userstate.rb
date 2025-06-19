#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Possible user states with reverse mapping
#
#------------------------------------------------------------------------------

module UserStates
  STATES = {
    privileged: 0,
    regular: 1,
    nonexistent: 2
  }.freeze

  NAMES = STATES.invert.freeze

  def self.to_i(name)
    STATES.fetch(name) { raise ArgumentError, "Unknown user state name: #{name.inspect}" }
  end

  def self.to_sym(code)
    NAMES.fetch(code) { raise ArgumentError, "Unknown user state code: #{code.inspect}" }
  end

  def self.valid?(val)
    STATES.key?(val) || NAMES.key?(val)
  end
end
