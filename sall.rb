#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM

require "rubygems"
require "ollama-ai"
require "sqlite3"

#LLM = "gemma2:2b"
LLM = "gemma:2b"

DATA_FILE   = "salldata.sq3"
TALK_LENGTH = 1440 # 有効な会話時間[分]

def main
  dbh = get_dbh()
  talker = "Visiter"
  user_content = nil
  begin
    printf("%s >>> ", talker)
    user_content = gets
    if user_content
      if user_content.strip == ""
      elsif /^\s*name\s+(\S+)/ =~ user_content
        talker = $1
      elsif user_content.strip == "hist"
        get_hist(dbh, talker).each do |dir, content|
          printf("%s: %s\n", dir, content.to_s.strip)
        end
      else
        lastid = insert(dbh, talker, "user", user_content)
        pid = fork do
          asst_content = talk(dbh, talker, user_content)
        end
        th = Process::detach(pid) # 子プロセス監視スレッド
        while th.status
          sleep 0.5
        end
        asst_content = select(dbh, talker, "asst", lastid)
        printf("%s\n", asst_content)
      end
    end
  end while user_content
  printf("\n")
end

def talk(dbh, talker, user_content)
  messages = []
  # 初期知識を読み込む
  sql = "SELECT content FROM salltext WHERE dir = 'system' ORDER BY id"
  dbh.execute(sql) do |row|
    messages << { role: "system", content: row[0] }
  end
  # ユーザとの会話を読み込む
  asst_cnt = 0
  get_hist(dbh, talker).each do |dir, content|
    case dir
    when "assistant"
      messages << { role: "assistant", content: content }
      asst_cnt += 1
    when "user"
      messages << { role: "user",      content: content }
    end
  end
  if asst_cnt == 0
    messages << { role: "assistant", content: "質問はなんですか？" }
  end
  # ユーザの発言を追加
  messages << { role: "user", content: user_content }

  if $llm_client == nil
    $llm_client = Ollama::new(credentials: { address: "http://localhost:11434" },
                                            options: { server_sent_events: true })
  end
  asst_content = nil
  sql = "INSERT INTO salltext(wtime, talker, dir, content) VALUES(DATETIME('NOW'), ?, ?, ?)"
  dbh.transaction do
    result = $llm_client.chat({ model: LLM, messages: messages })
    asst_content = get_content(result)
    dbh.execute(sql, [talker, "asst", asst_content])
  end
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
  dbh = nil
  if !FileTest::exist?(DATA_FILE)
    sqls = []
    sqls << <<EOT
CREATE TABLE IF NOT EXISTS salltext (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  wtime   TEXT,
  talker  TEXT,
  dir     TEXT,
  content TEXT
)
EOT
    dbh = SQLite3::Database.new(DATA_FILE) 
    begin
      sqls.each do |sql|
        dbh.execute(sql)
      end
    rescue SQLite3::SQLException => err
      puts err
    end

    # 初期データの例
    insert(dbh, "", "system", "光子は電磁相互作用を媒介するゲージ粒子で、ガンマ線の正体であり γ で表されることが多い。")
    insert(dbh, "", "system", "ウィークボソンは弱い相互作用を媒介するゲージ粒子で、質量を持つ。")
    insert(dbh, "", "system", "Wボソンは電荷±1をもつウィークボソンで、ベータ崩壊を起こすゲージ粒子である。W+, W−で表され、互いに反粒子の関係にある。")
    insert(dbh, "", "system", "Zボソンは電荷をもたないウィークボソンで、ワインバーグ＝サラム理論により予言され、後に発見された。Z0 と書かれることもある。")
    insert(dbh, "", "system", "グルーオンは強い相互作用を媒介するゲージ粒子で、カラーSU(3)の下で8種類存在する（8重項）。")
    insert(dbh, "", "system", "XボソンとYボソンはジョージ＝グラショウ模型において導入される未発見のゲージ粒子である。")
    insert(dbh, "", "system", "重力子（グラビトン）は重力を媒介する未発見のゲージ粒子で、スピン2のテンソル粒子と考えられている。")
  else
    dbh = SQLite3::Database.new(DATA_FILE) 
  end
  return dbh
end

def insert(dbh, talker, dir, content)
  maxid = 0
  sql = "INSERT INTO salltext(wtime, talker, dir, content) VALUES(DATETIME('NOW'), ?, ?, ?)"
  dbh.transaction do
    dbh.execute(sql, [talker, dir, content])  
    dbh.execute("SELECT MAX(id) FROM salltext") do |rows|
      maxid = rows[0]
    end
  end
  return maxid
end

def select(dbh, talker, dir, lastid = nil)
  content = nil
  if lastid
    sql = "SELECT content FROM salltext WHERE talker = ? AND dir = ? AND id > ? ORDER BY ID"
    dbh.execute(sql, [talker, dir, lastid]) do |rows|
      content = rows[0]
    end
  else
    sql = "SELECT content FROM salltext WHERE id = (SELECT MAX(ID) FROM salltext WHERE talker = ? AND dir = ?)"
    dbh.execute(sql, [talker, dir]) do |rows|
      content = rows[0]
    end
  end
  return content
end

def get_hist(dbh, talker, max = nil)
  histarr = []
  sql = "SELECT dir, content FROM salltext WHERE talker = ? AND wtime >= DATETIME('NOW', '-#{TALK_LENGTH} MINUTES') ORDER BY id"
  dbh.execute(sql, [talker]) do |row|
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

