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

require_relative "test_helper"

class FakeDB
  attr_reader :added_users, :users

  def initialize
    @next_id = 1
    @added_users = []
    @users = {}  # userid -> [id, userid, username, privlevel]
  end

  def add_user(userid, privlevel, username)
    id = @next_id
    @next_id += 1
    @added_users << [id, userid, username, privlevel]
    @users[userid] = [id, userid, username, privlevel]
    id
  end

  def get_user_by_id(userid)
    users[userid]
  end
end

describe User do
  before do
    @dbl = FakeDB.new
    @userid = 42
    @name = "Alice"
  end

  describe "when creating a new user" do
    it "calls add_user on the DB and sets attributes" do
      user = User.new(@dbl, @userid, :regular, @name)
      
      assert_equal 1, @dbl.added_users.size
      id, uid, uname, upriv = @dbl.added_users.first
      assert_equal @userid, uid
      assert_equal @name, uname
      assert_equal UserStates.to_i(:regular), upriv

      assert_equal id,      user.id
      assert_equal @userid, user.userid
      assert_equal @name,   user.username
      assert_equal :regular, user.level
    end
  end

  describe "when loading an existing user" do
    before do
      @dbl.add_user(@userid, UserStates.to_i(:privileged), "Bob")
      @existing_record = @dbl.get_user_by_id(@userid)
    end

    it "loads the record instead of creating a new one" do
      user = User.new(@dbl, @userid)
      assert_equal 1, @dbl.added_users.size

      assert_equal @existing_record[0], user.id
      assert_equal @userid,            user.userid
      assert_equal "Bob",              user.username
      assert_equal :privileged,        user.level
      assert user.privileged?
      refute user.nonexistent?
    end
  end

  describe "when the user does not exist in DB" do
    it "marks the state as nonexistent" do
      user = User.new(@dbl, @userid)
      assert_equal :nonexistent, user.level
      assert user.nonexistent?
    end
  end

  describe "error handling" do
    it "raises if DB returns invalid privlevel code" do
      @dbl.users[@userid] = [1, @userid, "Charlie", 99]
      err = assert_raises(ArgumentError) { User.new(@dbl, @userid) }
      assert_match(/Invalid user state code: 99/, err.message)
    end
  end
end
