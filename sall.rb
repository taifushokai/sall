#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM

require "rubygems"
require "ollama-ai"
require "sqlite3"

TALK_LENGTH = 10 # 会話が続く時間[MINUTES]

def main
  dbh = get_dbh()
=begin
  # 初期知識の例
  insert(dbh, "_INIT_", "asst", "光子は電磁相互作用を媒介するゲージ粒子で、ガンマ線の正体であり γ で表されることが多い。")
  insert(dbh, "_INIT_", "asst", "ウィークボソンは弱い相互作用を媒介するゲージ粒子で、質量を持つ。")
  insert(dbh, "_INIT_", "asst", "Wボソンは電荷±1をもつウィークボソンで、ベータ崩壊を起こすゲージ粒子である。W+, W−で表され、互いに反粒子の関係にある。")
  insert(dbh, "_INIT_", "asst", "Zボソンは電荷をもたないウィークボソンで、ワインバーグ＝サラム理論により予言され、後に発見された。Z0 と書かれることもある。")
  insert(dbh, "_INIT_", "asst", "グルーオンは強い相互作用を媒介するゲージ粒子で、カラーSU(3)の下で8種類存在する（8重項）。")
  insert(dbh, "_INIT_", "asst", "XボソンとYボソンはジョージ＝グラショウ模型において導入される未発見のゲージ粒子である。")
  insert(dbh, "_INIT_", "asst", "重力子（グラビトン）は重力を媒介する未発見のゲージ粒子で、スピン2のテンソル粒子と考えられている。")
=end
  user_name = "Visiter"
  user_content = nil
  begin
    printf("%s >>> ", user_name)
    user_content = gets
    if user_content
      if /\s*user\s+(\S+)/ =~ user_content
        user_name = $1
      elsif user_content.strip == "hist"
        get_hist(dbh, user_name).each do |dir, content|
          printf("%s: %s\n", dir, content.to_s.strip)
        end
      else
        (asst_content, user_name) = talk(dbh, user_name, user_content)
        puts asst_content
      end
    end
    end while user_content
  puts
end

def talk(dbh, user_name, user_content)
  if /^_INIT_/ =~ user_name # 許容しないユーザ名
    user_name = "Someone"
  end

  messages = []
  # 初期知識を読み込む
  sql = "SELECT content FROM salltext WHERE talker LIKE '_INIT_%' AND dir = 'asst' ORDER BY id"
  dbh.execute(sql) do |row|
    messages << { role: "system", content: row[0] }
  end
  # ユーザとの会話を読み込む(1日以内)
  sql = "SELECT dir, content FROM salltext WHERE talker = ? AND utime >= DATETIME('NOW', '-#{TALK_LENGTH} MINUTES') ORDER BY id"
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

  if $llm_client == nil
    $llm_client = Ollama.new(credentials: { address: "http://localhost:11434" },
                                            options: { server_sent_events: true })
  end
  result = $llm_client.chat({ model: "gemma:2b", messages: messages })
  asst_content = get_content(result)
  insert(dbh, user_name, "user", user_content)
  insert(dbh, user_name, "asst", asst_content)
  return asst_content, user_name
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

def get_hist(dbh, user_name, max = nil)
  histarr = []
  sql = "SELECT dir, content FROM salltext WHERE talker = ? AND utime >= DATETIME('NOW', '-#{TALK_LENGTH} MINUTES') ORDER BY id"
  dbh.execute(sql, [user_name]) do |row|
    (dir, content) = *row
    case dir
    when "user"
      histarr << ["user", content]
    when "asst"
      histarr << ["assistant", content]
    end
  end
  if max
    max = max.to_i
    eoa = histarr.size - 1
    boa = eoa - max + 1
    boa = 0 if boa < 0
    histarr = histarr[boa .. eoa]
  end
  return histarr
end

main if __FILE__ == $0

