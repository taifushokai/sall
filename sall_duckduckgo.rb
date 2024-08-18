#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM / use DackDackGo

require "./sall.rb"
require "duckduckgo"
require "pp"

REZULTS_SIZE = 3

def main
  if ARGV.size == 0
    print("ex) sall_duckduckgo.rb SEARCH_WORD1 SEARCH_WORD2 ..\n")
  else
    dbh = get_dbh()
    ARGV.each do |word|
      results = DuckDuckGo::search(:query => word)
      results[0 .. (REZULTS_SIZE - 1)].each do |result|
        content = sprintf("%s: %s", result.title, result.description)
        printf("%s\n", content)
        insert(dbh, "_INIT_DUCKDUCKGO", "asst", content)
      end
    end
  end
end

def mainX
  dbh = get_dbh()
  begin
    sql = "DELETE FROM salltext WHERE talker NOT LIKE '_INIT_%' AND utime <= DATETIME('NOW', '-#{RETENTION_DAYS}')"
    dbh.execute(sql)
    sql = "VACUUM"
    dbh.execute(sql)
  rescue SQLite3::SQLException => err
    puts err
  end
end

main if __FILE__ == $0

