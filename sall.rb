#!/usr/bin/env -S ruby -Eutf-8
#
#= Ollama Chat

require "ollama-ai"
require "nkf"
require "natto"
require "duckduckgo"
require "wikipedia"
require "sqlite3"

$DBG = false # text mode debug
NATTO_LANG = "UTF-8" # EUC-JP"
INIT_FILE  = "sall_init.txt"
DATA_FILE  = "sall_data.sq3"

#LLMODEL = "gemma:2b"
#LLMODEL = "qwen2.5:1.5b"
#LLMODEL = "7shi/tanuki-dpo-v1.0:latest"
LLMODEL = "llama3.2:1b"

ROLL_SYSTEM = "system"
ROLL_ASSISTANT = "assistant"
ROLL_USEER = "user"

ASSISTANT_DEF = "Assistant"
USER_DEF = "Visitor"


$llm_client = nil
$parser = nil

#=== main
def main()
  assistant_name = ASSISTANT_DEF
  user_name = USER_DEF
  pasttalk = ""
  loop do
    if user_name == "Visitor"
      printf("%s あなた > ", Time::now.strftime("%T"))
    else
      printf("%s %s > ", Time::now.strftime("%T"), user_name) 
    end
    getbuf = gets()
    if getbuf == nil
      printf("\n")
      break
    end
    user_sentence = getbuf.strip
    cliches = user_sentence[0..80].downcase.strip
    if cliches == ""
    elsif cliches == "bye"
      break
    elsif /you're\s+(\S+)/i =~ cliches
      assistant_name = $1
    elsif /i'm\s+(\S+)/i =~ cliches
      user_name = $1
    else
      time0 = Time::now
      dbh = get_dbh()
      assistant_sentence = talk(dbh, assistant_name, user_name, user_sentence, pasttalk)
      dbh.close
      time = Time::now - time0
      printf("%s(%.1f) %s : %s\n", Time::now.strftime("%T"), time, assistant_name, assistant_sentence)
      nowstr = Time::now.strftime("%F %T")
      pasttalk = sprintf("時刻 %s のユーザの「%s」としての発言: %s\n" \
        +             "時刻 %s のassistantの「%s」としての発言: %s\n", \
        nowstr, nowstr, user_name, user_sentence, assistant_name, assistant_sentence)
    end
  end
end

#=== 会話
def talk(dbh, assistant_name, user_name, user_sentence, pasttalk)
  if $llm_client == nil
    $llm_client = Ollama::new(credentials: { address: "http://localhost:11434" },
                                  options: { server_sent_events: true })
  end
  system_content = ""
  # 語句の問い合わせ
  inquiry_results = inquiry(dbh, user_sentence, [assistant_name, user_name])
  if inquiry_results
    system_content += inquiry_results
  end
  # 名前のの設定
  if assistant_name != ASSISTANT_DEF
    system_content += "#{ROLL_ASSISTANT} は #{assistant_name} の役です。\n"
  end
  if user_name != USER_DEF
    system_content += "#{ROLL_USEER} の名前は #{user_name} です。\n"
  end
  # プロフィールの読み込み
  open(INIT_FILE) do |rh|
    system_content += rh.read + "\n"
  end
  # 過去の会話の追加
  system_content += pasttalk.to_s
  # 現在時刻の追加
  system_content += sprintf("現在の時刻は %s\n", Time::now.strftime("%F %T"))
  messages = []
  system_content.each_line do |line|
    messages << {"role": ROLL_SYSTEM, "content": line}
  end
  messages << {"role": ROLL_ASSISTANT, "content": "質問に簡潔に答えます。"}
  messages << {"role": ROLL_USEER, "content": user_sentence}
  #puts messages
  chatdata = {
    model: LLMODEL,
    messages: messages
  }
  response = $llm_client.chat(chatdata)
  assistant_sentence = get_content(response)
  if /^\(.+?として\)/ =~ assistant_sentence
    assistant_sentence = Regexp.last_match.post_match
  elsif /『(.+?)』/ =~ assistant_sentence
    assistant_sentence = $1
  end
  return assistant_sentence
end

#=== メッセージの取得
def get_content(response)
  content = ""
  response.each do |hash|
    message = hash["message"]
    if message and message["role"] == ROLL_ASSISTANT
      content += message["content"].to_s
    end
  end
  content.gsub!("</start_of_turn>", "")
  content.gsub!("</end_of_turn>", "")
  content.strip!
  return content
end

#=== 語の説明を求める
def inquiry(dbh, sentence, exclusions = [])
  inquiry_results = ""
  unless $parser
    $parser = Natto::MeCab.new
  end
  sentence = NKF::nkf("-e", sentence) if NATTO_LANG != "UTF-8"
  nounarr = []
  noun = ""
  nountype = ""
  nouncont = false
  parsedtext = $parser.parse(sentence)
  parsedtext.each_line do |line|
    line = NKF::nkf("-w", line).scrub if NATTO_LANG != "UTF-8"
    if /^(.+?)\t名詞,(.+?),/ =~ line
      noun << $1
      if nouncont
        nountype = "熟語"
      else
        nountype = $2
      end
      nouncont = true
    else
      nounarr << [noun, nountype]
      noun = ""
      nountype = ""
      nouncont = false
    end
  end
  if nouncont
    nounarr << [noun, nountype]
  end
  nounarr.each do |noun, nountype|
    if exclusions.include?(noun) # 除外語
      printf("(exclusion) %s\n", noun) if $DBG
    elsif ["一般", "代名詞", "サ変接続", "副詞可能", "時相名詞", "数詞"].member?(nountype)
      printf("(%s) %s\n", nountype, noun) if $DBG
    else
      # データベースで説明を求める
      descrip = select(dbh, noun)
      if descrip
        inquiry_results << sprintf("%s : %s\n", noun, descrip)
        printf("(Database/%s) %s\n", nountype, noun) if $DBG
      else
        # Wikipedia で説明を求める
        result = nil
        begin
          unless $wkpclient
            $wkpclient = Wikipedia::Client::new(Wikipedia::Configuration.new(domain: 'ja.wikipedia.org'))
          end
          result = $wkpclient.find(noun)
        rescue
        end
        if result and result.summary
          inquiry_results << sprintf("%s : %s\n", noun, result.summary.strip)
          insert(dbh, noun, result.summary.strip, "WIKIPEDIA", level = "F")
          printf("(Wikipedia/%s) %s\n", nountype, result.title.strip) if $DBG
        else
          # DuckDuckGo で説明を求める
          results = DuckDuckGo::search(:query => noun)
          if results[0]
            inquiry_results << sprintf("%s : %s\n", noun, results[0].description.strip)
            insert(dbh, noun, results[0].description.strip, "DUCKDUCKGO", level = "G")
            printf("(DuckDuckGo/%s) %s\n", nountype, results[0].title.strip) if $DBG
          end
        end
      end
    end
  end
  return inquiry_results
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

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  $DBG = true
  main()
end
