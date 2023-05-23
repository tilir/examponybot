#------------------------------------------------------------------------------
#
# Telegram bot for peering exam on programming
# Licensed after GNU GPL v3
#
#------------------------------------------------------------------------------
#
# Data base layer to abstract out SQLite details
#
#------------------------------------------------------------------------------

require 'sqlite3'

def create_db_structure(db)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY,
      userid INTEGER,
      username TEXT,
      privlevel INTEGER
    );
  SQL
end

class User
  attr_accessor :userid
  attr_accessor :username
  attr_accessor :privlevel
  def initialize(userid, username, privlevel)
    @userid = userid
    @username = username
    @privlevel = privlevel
  end
end

class DBLayer
  def initialize(dbname, verbose)
    @db = SQLite3::Database.new(dbname)
    @verbose = verbose
    create_db_structure(@db)
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def add_user(tguser, priv, name)
    @db.execute('INSERT INTO users (userid, username, privlevel) VALUES (?, ?, ?)', [tguser.id, name, priv])
    p "user #{name} added with priv level #{priv}" if @verbose
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def get_user_by_id(id)
    rs = @db.get_first_row('SELECT * FROM users WHERE userid = ?', [id])
    return nil if rs.empty?

    p "got user info: #{rs[1]} #{rs[2]} #{rs[3]}" if @verbose
    return User.new(rs[1], rs[2], rs[3])
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def users_empty?
    rs = @db.execute('SELECT * FROM users')
    p "user table empty" if @verbose and rs.empty?
    rs.empty?
  rescue SQLite3::Exception => e
    puts e
    close
    exit(1)
  end

  def close
    @db.close if @db
  end
end
