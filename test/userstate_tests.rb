# frozen_string_literal: true

#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for user states
#
#------------------------------------------------------------------------------

require_relative 'test_helper'

describe UserStates do
  describe '.to_i' do
    it 'returns the correct integer code for a valid state name' do
      assert_equal 0, UserStates.to_i(:privileged)
      assert_equal 1, UserStates.to_i(:regular)
      assert_equal 2, UserStates.to_i(:nonexistent)
    end

    it 'raises ArgumentError for an unknown state name' do
      err = assert_raises(ArgumentError) { UserStates.to_i(:foo) }
      assert_match(/Unknown user state name: :foo/, err.message)
    end
  end

  describe '.to_sym' do
    it 'returns the correct symbol for a valid code' do
      assert_equal :privileged,  UserStates.to_sym(0)
      assert_equal :regular,     UserStates.to_sym(1)
      assert_equal :nonexistent, UserStates.to_sym(2)
    end

    it 'raises ArgumentError for an unknown state code' do
      err = assert_raises(ArgumentError) { UserStates.to_sym(99) }
      assert_match(/Unknown user state code: 99/, err.message)
    end
  end

  describe '.valid?' do
    it 'returns true for valid state names and codes' do
      assert UserStates.valid?(:privileged)
      assert UserStates.valid?(:regular)
      assert UserStates.valid?(:nonexistent)
      assert UserStates.valid?(0)
      assert UserStates.valid?(1)
      assert UserStates.valid?(2)
    end

    it 'returns false for invalid names and codes' do
      refute UserStates.valid?(:bar)
      refute UserStates.valid?(42)
      refute UserStates.valid?(nil)
    end
  end
end
