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
    STDOUT.puts(message) if @@verbose
  end

  def self.error(message)
    STDERR.puts(message)
  end
end
