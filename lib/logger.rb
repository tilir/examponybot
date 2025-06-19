# frozen_string_literal: true

#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Simple logger
#
#------------------------------------------------------------------------------

class Logger
  @@verbose = false

  def self.set_verbose(value)
    @@verbose = !!value
  end

  def self.verbose?
    @@verbose
  end

  def self.print(message)
    puts(message) if @@verbose
  end
end
