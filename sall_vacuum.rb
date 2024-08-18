#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM / VACUUME sqlite data

require "./sall.rb"

RETENTION_DAYS = 2 # 会話保管期間[DAYS]

def main
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

