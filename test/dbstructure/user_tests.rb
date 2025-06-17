#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for user database descr
#
#------------------------------------------------------------------------------

require "test_helper"

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'dbstructure'

class FakeDB
  attr_reader :logs, :users

  def initialize
    @logs = []
    @next_id = 1
    initialize_managers
  end

  def transaction
    yield # Simple transaction simulation
  end

  private

  def initialize_managers
    @users = FakeUserManager.new(self)
  end
end

class FakeUserManager
  def initialize(db)
    @db = db
    @storage = {}
  end

  def add_user(userid, privlevel, username)
    record = DBUser.new(@db.next_id, userid, username, privlevel)
    @storage[userid] = record
    @db.logs << [:add_user, record]
    record
  end

  def get_user_by_id(userid)
    @storage[userid]
  end

  def all_users
    @storage.values
  end
end

# Helper method to get next ID
class FakeDB
  def next_id
    id = @next_id
    @next_id += 1
    id
  end
end

describe User do
  let(:db) { FakeDB.new }
  let(:user_id) { 10 }
  let(:privilege_level) { :regular }
  let(:username) { "Nobody" }

  describe "user creation" do
    it "persists new user with correct attributes" do
      # Exercise
      user = User.new(db, user_id, privilege_level, username)

      # Verify database interaction
      assert_equal 1, db.users.all_users.size
      db_record = db.users.all_users.first
      assert_equal user_id, db_record.userid
      assert_equal username, db_record.username
      assert_equal UserStates.to_i(privilege_level), db_record.privlevel

      # Verify object state
      assert_equal db_record.id, user.id # id
      assert_equal user_id, user.userid
      assert_equal username, user.username
      assert_equal privilege_level, user.level
      assert user.regular?
    end
  end

  describe "loading existing user" do
    before do
      db.users.add_user(user_id, UserStates.to_i(:privileged), "Bob")
      @existing_record = db.users.get_user_by_id(user_id)
    end

    it "loads user data without creating new record" do
      # Exercise
      user = User.new(db, user_id)

      # Verify
      assert_equal 1, db.users.all_users.size, "Should not add new record"
      assert_equal @existing_record.id, user.id
      assert_equal "Bob", user.username
      assert_equal :privileged, user.level
      assert user.privileged?
    end
  end

  describe "nonexistent users" do
    it "marks unknown users as nonexistent" do
      # Exercise
      user = User.new(db, 999)

      # Verify
      assert_equal :nonexistent, user.level
      assert user.nonexistent?
      refute user.regular?
      refute user.privileged?
    end
  end

  describe "state predicates" do
    it "correctly identifies all user states" do
      # Privileged user
      privileged = User.new(db, 1, :privileged, "Admin")
      assert privileged.privileged?
      refute privileged.regular?

      # Regular user
      regular = User.new(db, 2, :regular, "Regular")
      assert regular.regular?
      refute regular.privileged?
      refute regular.nonexistent?

      # Nonexistent user
      nonexistent = User.new(db, 999)
      assert nonexistent.nonexistent?
    end
  end
end
