require 'sqlite3'

class DBRunner
  
  def initialize(db_name)
    @db = SQLite3::Database.open(db_name)
  end
  
  def execute(query)
    @db.execute(query)
  end
  
end
