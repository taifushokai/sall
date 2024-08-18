#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM

require "rubygems"
require "ollama-ai"
require "sqlite3"
require "pp"

def main
  dbh = get_dbh()
=begin
  insert(dbh, "INIT", "asst", "光子は電磁相互作用を媒介するゲージ粒子で、ガンマ線の正体であり γ で表されることが多い。")
  insert(dbh, "INIT", "asst", "ウィークボソンは弱い相互作用を媒介するゲージ粒子で、質量を持つ。")
  insert(dbh, "INIT", "asst", "Wボソンは電荷±1をもつウィークボソンで、ベータ崩壊を起こすゲージ粒子である。W+, W−で表され、互いに反粒子の関係にある。")
  insert(dbh, "INIT", "asst", "Zボソンは電荷をもたないウィークボソンで、ワインバーグ＝サラム理論により予言され、後に発見された。Z0 と書かれることもある。")
  insert(dbh, "INIT", "asst", "グルーオンは強い相互作用を媒介するゲージ粒子で、カラーSU(3)の下で8種類存在する（8重項）。")
  insert(dbh, "INIT", "asst", "XボソンとYボソンはジョージ＝グラショウ模型において導入される未発見のゲージ粒子である。")
  insert(dbh, "INIT", "asst", "重力子（グラビトン）は重力を媒介する未発見のゲージ粒子で、スピン2のテンソル粒子と考えられている。")
=end
  user_content = nil
  begin
    user_name = "Visiter"
    print ">>> "
    user_content = gets
    if user_content
      puts talk(dbh, user_name, user_content)
    end
    end while user_content
  puts
end

def talk(dbh, user_name, user_content)
  if $llm_client == nil
    $llm_client = Ollama.new(credentials: { address: "http://localhost:11434" },
                                            options: { server_sent_events: true })
  end

  messages = []
  # 初期知識を読み込む
  sql = "SELECT content FROM salltext WHERE talker = 'INIT' AND dir = 'asst' ORDER BY id"
  dbh.execute(sql) do |row|
    messages << { role: "assistant", content: row[0] }
  end
  # ユーザとの会話を読み込む(1日以内)
  sql = "SELECT dir, content FROM salltext WHERE talker = ? AND utime >= DATETIME('NOW', '-1 DAYS') ORDER BY id"
  dbh.execute(sql, [user_name]) do |row|
    (dir, content) = *row
    case dir
    when "user"
      messages << { role: "user",      content: content }
    when "asst"
      messages << { role: "assistant", content: content }
    end
  end
  # ユーザの発言を追加
  messages << { role: "user", content: user_content }
  result = $llm_client.chat({ model: "gemma:2b", messages: messages })
  asst_content = get_content(result)
  insert(dbh, user_name, "user", user_content)
  insert(dbh, user_name, "asst", asst_content)
  return asst_content
end

def get_content(result)
  content = ""
  result.each do |hash|
    message = hash["message"]
    if message and message["role"] == "assistant"
      content += message["content"].to_s
    end
  end
  return content
end

def get_dbh()
  dbh = SQLite3::Database.new("salldata.sq3") 
  sql = <<EOT
CREATE TABLE IF NOT EXISTS salltext (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  utime   TEXT,
  talker  TEXT,
  dir     TEXT,
  content TEXT
);
EOT
  begin
    dbh.execute(sql)
  rescue SQLite3::SQLException => err
    puts err
  end
  return dbh
end

def insert(dbh, talker, dir, content)
  sql = "INSERT INTO salltext(utime, talker, dir, content) VALUES(DATETIME('NOW'), ?, ?, ?)"
  dbh.execute(sql, [talker, dir, content])  
end

def get_hist(dbh, user_name)
  sql = "SELECT dir, content FROM salltext WHERE talker = ? AND utime >= DATETIME('NOW', '-1 DAYS') ORDER BY id"
  dbh.execute(sql, [user_name]) do |row|
    (dir, content) = *row
    case dir
    when "user"
      messages << { role: "user",      content: content }
    when "asst"
      messages << { role: "assistant", content: content }
    end
  end
end

main if __FILE__ == $0
