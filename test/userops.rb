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

describe DBLayer do
  before do
    @tmpfile = Tempfile.new('test.db')
    @dbl = DBLayer.new(@tmpfile.path)
  end

  after do
    @dbl.close
    @tmpfile.unlink
  end

  describe '#add_user' do
    it 'adds a new user and returns its id' do
      uid = @dbl.add_user(100, 1, 'User100')
      refute_nil uid

      user = @dbl.get_user_by_id(100)
      assert_equal 100, user[1]
      assert_equal 'User100', user[2]
      assert_equal 1, user[3]
    end

    it 'updates username when user already exists but does not change priv level' do
      uid1 = @dbl.add_user(101, 1, 'User101')
      uid2 = @dbl.add_user(101, 2, 'User101Updated')
      assert_equal uid1, uid2

      user = @dbl.get_user_by_id(101)
      assert_equal 'User101Updated', user[2]
      # Привилегии не должны измениться
      assert_equal 1, user[3]
    end

    it 'adds multiple distinct users' do
      uid1 = @dbl.add_user(200, 1, 'Alpha')
      uid2 = @dbl.add_user(201, 2, 'Beta')

      refute_equal uid1, uid2

      users = @dbl.all_users.map { |u| u.instance_variable_get(:@userid) }
      assert_includes users, 200
      assert_includes users, 201
    end

    it 'accepts very long username string' do
      long_name = 'u' * 500
      uid = @dbl.add_user(350, 1, long_name)
      refute_nil uid

      user = @dbl.get_user_by_id(350)
      refute_nil user
      assert_equal long_name, user[2]
    end

    it 'accepts username with special characters' do
      special_name = 'user!@# $%^&*()'
      uid = @dbl.add_user(360, 1, special_name)
      refute_nil uid

      user = @dbl.get_user_by_id(360)
      refute_nil user
      assert_equal 360, user[1]
    end

    it 'returns the same id when updating an existing user and updates username' do
      id1 = @dbl.add_user(12345, 1, 'Alice')
      id2 = @dbl.add_user(12345, 1, 'AliceUpdated')

      assert_equal id1, id2

      user = @dbl.get_user_by_id(12345)
      assert_equal 'AliceUpdated', user[2]
    end

    it 'raises error if tguser is nil' do
      assert_raises(ArgumentError) { @dbl.add_user(nil, 1, 'Bob') }
    end

    it 'raises error if priv is nil' do
      assert_raises(ArgumentError) { @dbl.add_user(123, nil, 'Bob') }
    end

    it 'raises error if name is nil' do
      assert_raises(ArgumentError) { @dbl.add_user(123, 1, nil) }
    end
  end

  describe '#get_user_by_id' do
    it 'returns user row when user exists' do
      @dbl.add_user(400, 1, 'User400')
      user = @dbl.get_user_by_id(400)
      refute_nil user
      assert_equal 400, user[1]
      assert_equal 'User400', user[2]
    end

    it 'returns nil when user does not exist' do
      user = @dbl.get_user_by_id('nonexistent')
      assert_nil user
    end

    it 'returns nil when called with nil' do
      user = @dbl.get_user_by_id(nil)
      assert_nil user
    end
  end

  describe '#users_empty?' do
    it 'returns true on fresh DB' do
      assert @dbl.users_empty?
    end

    it 'returns false after adding users' do
      @dbl.add_user(500, 1, 'User500')
      refute @dbl.users_empty?
    end
  end

  describe '#all_users' do
    it 'returns empty array if no users' do
      assert_equal [], @dbl.all_users
    end

    it 'returns array of User objects for all users' do
      @dbl.add_user(600, 1, 'User600')
      @dbl.add_user(601, 1, 'User601')

      users = @dbl.all_users
      assert_equal 2, users.size
      assert users.all? { |u| u.is_a?(User) }

      ids = users.map { |u| u.instance_variable_get(:@userid) }
      assert_includes ids, 600
      assert_includes ids, 601
    end
  end

  describe '#all_nonpriv_users' do
    it 'returns empty array if no users with privlevel = 1' do
      assert_equal [], @dbl.all_nonpriv_users
    end

    it 'returns only users with privlevel = 1' do
      @dbl.add_user(700, 1, 'NonPrivUser')
      @dbl.add_user(701, 2, 'PrivUser')

      nonpriv = @dbl.all_nonpriv_users
      assert_equal 1, nonpriv.size
      assert_equal 700, nonpriv.first.instance_variable_get(:@userid)
    end
  end
end
