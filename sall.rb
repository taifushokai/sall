#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI

require "ollama-ai"
require "nkf"
require "natto"
require "duckduckgo"
require "wikipedia"
require "./salltexts_util.rb"
require "./sallwords_util.rb"

$DBG = false # text mode debug
NATTO_LANG = "UTF-8" # EUC-JP"
INIT_FILE  = "sall_init.txt"

$OLLAMA_URL = "http://localhost:11434"
$LLMODEL = "llama3.2:1b"

ROLL_SYSTEM = "system"
ROLL_ASSISTANT = "assistant"
ROLL_USEER = "user"

ASSISTANT_DEF = "Assistant"
USER_DEF = "Visitor"


$llm_client = nil
$parser = nil

#=== main
def main()
  $DBG = true
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
    elsif /\A===/ =~ getbuf or /\A@text/ =~ getbuf
      getbuf << STDIN.read.to_s.strip
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
      user_sentence, assistant_sentence, model, insize, outsize = talk(dbh, assistant_name, user_name, user_sentence, pasttalk)
      dbh.close
      time = Time::now - time0
      printf("%s(%.1f sec,%s,%d,%d) %s : %s\n", Time::now.strftime("%T"), time, model, insize, outsize, assistant_name, assistant_sentence)
      nowstr = Time::now.strftime("%F %T")
      pasttalk = sprintf("時刻 %s のユーザの「%s」としての発言: %s\n" \
        +             "時刻 %s のassistantの「%s」としての発言: %s\n", \
        nowstr, nowstr, user_name, user_sentence, assistant_name, assistant_sentence)
    end
  end
end

#=== 会話
def talk(dbh, assistant_name, user_name, user_sentence, pasttalk)
  system_content = read_init()
  user_sentence.strip!
  if /\A===/ =~ user_sentence
    rest = Regexp.last_match.post_match
    (words, descrip) = rest.split(/\n/, 2)
    words.to_s.split("|").each do |word|
      insert(dbh, word.strip, descrip)
    end
    user_sentence = sprintf("「%s」とは", words)
    assistant_sentence = descrip
    insize = 0
    outsize = 0
  elsif /\A@list$/i =~ user_sentence
    user_sentence = ""
    assistant_sentence = "\n" + list(dbh)
    insize = 0
    outsize = 0
  elsif /\A@del\s+(\d+)/i =~ user_sentence
    pid = $1.to_i
    delete(dbh, pid)
    user_sentence = ""
    assistant_sentence = ""
    insize = 0
    outsize = 0
  elsif /\A@delall$/i =~ user_sentence
    clear(dbh)
    user_sentence = ""
    assistant_sentence = ""
    insize = 0
    outsize = 0
  elsif /\A@listtext$/i =~ user_sentence
    user_sentence = ""
    assistant_sentence = "\n" + list_texts()
    insize = 0
    outsize = 0
  elsif /\A@text$/i =~ user_sentence
    if /===/ =~ user_sentence
      rest = Regexp.last_match.post_match
      (words, descrip) = rest.split(/\n/, 2)
      insert_text(words, descrip)
      user_sentence = sprintf("「%s」とは", words)
      assistant_sentence = descrip
    else
      user_sentence = ""
      assistant_sentence = ""
    end
    insize = 0
    outsize = 0
  else
    # 名前のの設定
    if assistant_name != ASSISTANT_DEF
      system_content += "#{ROLL_ASSISTANT} は #{assistant_name} の役です。\n"
    end
    if user_name != USER_DEF
      system_content += "#{ROLL_USEER} の名前は #{user_name} です。\n"
    end

    # 語句の問い合わせ
    inquiry_results = inquiry(dbh, user_sentence, [assistant_name, user_name])
    if inquiry_results
      system_content += inquiry_results
    end

    # 過去の会話の追加
    system_content += pasttalk.to_s

    # 現在時刻の追加
    system_content += sprintf("現在の時刻は %s\n", Time::now.strftime("%F %T"))

    messages = []
    system_content.each_line do |line|
      messages << {"role": ROLL_SYSTEM, "content": line}
    end
    messages << {"role": ROLL_ASSISTANT, "content": "答えられる範囲で質問に答えます。"}
    messages << {"role": ROLL_USEER, "content": user_sentence}
    ##puts messages
    chatdata = {
      model: $LLMODEL,
      messages: messages
    }
    insize = chatdata.to_s.size
    if $llm_client == nil
      $llm_client = Ollama::new(credentials: { address: $OLLAMA_URL },
                                    options: { server_sent_events: true })
    end
    response = $llm_client.chat(chatdata)
    outsize = response.to_s.size
    assistant_sentence = get_content(response)
    if /^\(.+?として\)/ =~ assistant_sentence
      assistant_sentence = Regexp.last_match.post_match
    elsif /『(.+?)』/ =~ assistant_sentence
      assistant_sentence = $1
    end
  end
  return user_sentence, assistant_sentence, $LLMODEL, insize, outsize
end

#=== 設定ファイル読み込み
def read_init()
  system_content = ""
  setting = false
  open(INIT_FILE) do |rh|
    rh.each_line do |line|
      if /^\^\^\^/ =~ line
        setting = true
      else
        if setting
          if    /^ollama_url:\s+(\S+)/ =~ line
            ollama_url = $1
            if ollama_url != $OLLAMA_URL
              $OLLAMA_URL = ollama_url
              $llm_client = nil
            end
          elsif /^llmodel:\s+(\S+)/ =~ line
            $LLMODEL = $1
          elsif /^texts_dir:\s+(\S+)/ =~ line
            init_texts($1)
          end
        else
          system_content += line
        end
      end
    end
  end
  return system_content
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

  # 名詞の抽出
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
    elsif /^(.+?)\t接頭詞,(名詞接続),/ =~ line
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

  # 名詞の説明を取得する
  nounarr.each do |noun, nountype|
    # テキストで説明を求める(比較的長文)
    descrip = refer_text(noun)
    if descrip
      inquiry_results << sprintf("%s\n", descrip)
      printf("(Text/%s) %s\n", nountype, noun) if $DBG
    else
      # データベースでキャッシュを取得する
      descrip = select(dbh, noun)
      if descrip
        inquiry_results << sprintf("%s : %s\n", noun, descrip)
        printf("(Database/%s) %s\n", nountype, noun) if $DBG
      else
        if exclusions.include?(noun) # 除外語
          printf("(exclusion) %s\n", noun) if $DBG
        elsif ["一般", "代名詞", "サ変接続", "副詞可能", "時相名詞", "数詞", "非自立"].member?(nountype) # 除外名詞
          printf("(%s) %s\n", nountype, noun) if $DBG
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
  end
  return inquiry_results
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  $DBG = true
  main()
end

