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
  elsif ARGV[0] == "UPDATE"
    update()
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
      printf("===%d %s %s %s\n", pid, level, source, wtime)
      printf("%s\n%s\n^^^\n", word, descrip)
    end
  dbh.close
end

#=== テキストによる更新
def update()
  dbh = get_dbh()
  cmd     = nil
  pid     = nil
  word    = nil
  descrip = nil
  level   = nil
  source  = nil
  wtime   = nil
  STDIN.each_line do |line|
    if /^===(\w+)/ =~ line
      cmd = $1
      rest = Regexp.last_match.post_match
      if /(\w+)/ =~ rest
        level = $1
        rest = Regexp.last_match.post_match
        if /(\w+)/ =~ rest
          source = $1
          rest = Regexp.last_match.post_match
          if /(\w+)/ =~ rest
            begin
              wtime = Time::parse(rest)
            rescue
              wtime = nil
            end
          end
        end
      end
      if /^(\d+)$/ =~ cmd
        pid = $1.to_i # UPDATEモード
      elsif cmd == "ADD"
        pid = nil # INSERTモード
      elsif /^DEL(\d+)/ =~ cmd
        delid = $1.to_i
        dbh.transaction do
          dbh.execute("DELETE FROM sallwords WHERE id = ?", [delid])
        end
        STDERR.printf("DELETE %d\n", delid)
      elsif cmd == "DELALL"
        dbh.transaction do
          dbh.execute("DELETE FROM sallwords")
        end
        STDERR.printf("DELETE ALL\n")
      end
    elsif /^\^\^\^$/ =~ line
      if cmd and word and descrip
        word.strip!
        descrip.strip!
        level = "C" if level == nil
        source = "MANUAL" if source == nil
        wtime = Time::now.utc.strftime("%F %T")
        dbh.transaction do
          if pid
            dbh.execute("SELECT COUNT(*) FROM sallwords WHERE id = ?", [pid]) do |rows|
              if rows[0] == 0
                pid = nil # INSERTモード
              end
            end
          end
          if pid # pid があれば UPDATE モード
            sql = "UPDATE sallwords SET word = ?, descrip = ?, source = ?, level = ?, wtime = ? WHERE ID = ?"
            dbh.execute(sql, [word, descrip, source, level, wtime, pid])
          else
            sql = "INSERT INTO sallwords(word, descrip, source, level, wtime) VALUES(?, ?, ?, ?, ?)"
            dbh.execute(sql, [word, descrip, source, level, wtime])
          end
        end
      end 
      cmd     = nil
      pid     = nil
      word    = nil
      descrip = nil
      level   = nil
      source  = nil
      wtime   = nil
    else
      if word == nil
        word = line.to_s
        descrip = ""
      else
        descrip << line.to_s
      end
    end
  end
  dbh.close
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  $DBG = true
  main()
end

