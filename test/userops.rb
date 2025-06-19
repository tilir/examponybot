#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Tests for dblayer user operations
#
#------------------------------------------------------------------------------

require 'minitest/autorun'
require 'tempfile'
require 'dblayer'

describe 'User Operations' do
  before do
    @tmpfile = Tempfile.new('test.db')
    @db = DBLayer.new(@tmpfile.path)
  end

  after do
    @db.close
    @tmpfile.unlink
  end

  describe 'User creation' do
    it 'adds new user and can retrieve it' do
      user = User.new(@db, 100, UserStates.to_i(:regular), 'User100')
      refute_nil user.id

      found = @db.users.get_user_by_id(100)
      assert_equal 100, found.userid
      assert_equal 'User100', found.username
      assert_equal UserStates.to_i(:regular), found.privlevel
    end

    it 'updates username and privilege level when user exists' do
      user1 = User.new(@db, 101, UserStates.to_i(:regular), 'User101')
      user2 = User.new(@db, 101, UserStates.to_i(:privileged), 'User101Updated')

      assert_equal user1.id, user2.id
      assert_equal 'User101Updated', user2.username
      refute user2.regular?
    end

    it 'handles long usernames' do
      long_name = 'u' * 500
      user = User.new(@db, 350, UserStates.to_i(:regular), long_name)

      found = @db.users.get_user_by_id(350)
      assert_equal long_name, found.username
      assert_equal long_name, user.username
    end

    it 'handles special characters in username' do
      special_name = 'user!@# $%^&*()'
      user = User.new(@db, 360, UserStates.to_i(:regular), special_name)

      found = @db.users.get_user_by_id(360)
      assert_equal special_name, found.username
      assert_equal special_name, user.username
    end

    it 'raises error for nil parameters' do
      assert_raises(ArgumentError) { User.new(@db, nil, 1, 'Bob') }
      assert_raises(ArgumentError) { User.new(nil, 123, 1, 'Bob') }
      User.new(@db, 123, nil, nil) # fail if assertion failure here
    end
  end

  describe 'User retrieval' do
    before do
      @user = User.new(@db, 400, UserStates.to_i(:regular), 'User400')
    end

    it 'finds existing user' do
      found = @db.users.get_user_by_id(400)
      assert_equal @user.id, found.id
      assert_equal 'User400', found.username
    end

    it 'returns nil for non-existent user' do
      assert_nil @db.users.get_user_by_id('nonexistent')
      assert_nil @db.users.get_user_by_id(nil)
    end
  end

  describe 'User collections' do
    before do
      @regular = User.new(@db, 500, UserStates.to_i(:regular), 'RegularUser')
      @privileged = User.new(@db, 501, UserStates.to_i(:privileged), 'PrivilegedUser')
    end

    it 'checks empty state' do
      new_db = DBLayer.new(':memory:')
      assert new_db.users.empty?
      new_db.close
    end

    it 'lists all users' do
      users = @db.users.all
      assert_equal 2, users.size
      assert_equal [500, 501], users.map(&:userid).sort
    end

    it 'filters non-privileged users' do
      nonpriv = @db.users.all_nonpriv
      assert_equal 1, nonpriv.size
      assert_equal 500, nonpriv.first.userid
    end
  end
end
