#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI
# dump/update sallwords

require "sqlite3"
require "time"

DATA_FILE  = "sall_data.sq3"

#=== main
def main()
  if ARGV[0] == "DUMP"
    dump()
  elsif ARGV[0] == "CLEAR"
    dbh = get_dbh()
    clear(dbh)
  elsif ARGV[0] == "INPUT"
    input()
  else
    printf("ex) sallwords_util.rb DUMP > dump.txt\n")
    printf("ex) sallwords_util.rb UPDATE < dump.txt\n")
  end
end

#=== データベースハンドラの取得
def get_dbh()
  dbh = nil
  if !FileTest::exist?(DATA_FILE)
    sqls = []
    sqls << <<EOT
CREATE TABLE IF NOT EXISTS sallwords (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  word    TEXT,
  descrip TEXT,
  source  TEXT,
  level   TEXT,
  wtime   TEXT
)
EOT
    sqls << <<EOT
CREATE INDEX sallwords_word ON sallwords (word)
EOT
    dbh = SQLite3::Database.new(DATA_FILE) 
    begin
      sqls.each do |sql|
        dbh.execute(sql)
      end
    rescue SQLite3::SQLException => err
      puts err
    end
  else
    dbh = SQLite3::Database.new(DATA_FILE)
  end
  return dbh
end

#=== 語の記憶
def insert(dbh, word, descrip, source = "MANUAL", level = "C")
  maxid = 0
  sql = "INSERT INTO sallwords(word, descrip, source, level, wtime) VALUES(?, ?, ?, ?, DATETIME('NOW'))"
  dbh.transaction do
    dbh.execute(sql, [word, descrip, source, level])  
    dbh.execute("SELECT MAX(id) FROM sallwords") do |rows|
      maxid = rows[0]
    end
  end
  return maxid
end

#=== 語のリスト
def list(dbh)
  buff = ""
  sql = "SELECT id, word FROM sallwords ORDER BY id DESC"
  dbh.execute(sql, []) do |rows|
    buff << sprintf("%d %s\n", rows[0], rows[1])
  end
  return buff
end

#=== 語の検索
def select(dbh, word, source = nil)
  descrip = nil
  if source
    sql = "SELECT descrip FROM sallwords WHERE word = ? AND source = ? ORDER BY level, wtime DESC"
    dbh.execute(sql, [word, source]) do |rows|
      descrip = rows[0]
    end
  else
    sql = "SELECT descrip FROM sallwords WHERE word = ? ORDER BY level, wtime DESC"
    dbh.execute(sql, [word]) do |rows|
      descrip = rows[0]
      break
    end
  end
  return descrip
end

#=== 語の削除
def delete(dbh, pid)
  sql = "DELETE FROM sallwords WHERE id = ?"
  dbh.execute(sql, [pid])
end

#=== テーブルクリア
def clear(dbh)
  dbh.transaction do
    dbh.execute("DELETE FROM sallwords")
    dbh.execute("DELETE FROM sqlite_sequence WHERE name = 'sallwords'")
  end
end

#=== テキスト出力
def dump()
  dbh = get_dbh()
  sql = "SELECT id, word, descrip, source, level, wtime FROM sallwords ORDER BY id"
    dbh.execute(sql) do |rows|
      pid     = rows[0].to_i
      word    = rows[1].to_s.strip
      descrip = rows[2].to_s.strip
      source  = rows[3].to_s.strip
      level   = rows[4].to_s.strip
      wtime   = rows[5].to_s.strip
      printf("===%s\n%s\n^^^ %d %s %s %s\n", word, descrip, pid, source, level, wtime)
    end
  dbh.close
end

#=== テキストからの入力
def input()
  dbh = get_dbh()
  word    = nil
  descrip = nil
  source  = nil
  level   = nil
  STDIN.each_line do |line|
    if /^===(\S+)/ =~ line
      word    = $1.strip
      descrip = ""
      source  = ""
      level   = ""
    elsif /^\^\^\^(.*)/ =~ line
      params = $1.to_s.strip.split(/\s+/, 4)
      if word and descrip
        source = params[1]
        level  = params[2]
        insert(dbh, word, descrip, source, level)
      end
      word    = nil
      descrip = nil
      source  = nil
      level   = nil
    elsif word
      descrip << line
    end
  end
end

#= 直接呼ばれた場合は会話(CLI)
if __FILE__ == $PROGRAM_NAME
  $DBG = true
  main()
end

