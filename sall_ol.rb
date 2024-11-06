#!/usr/local/bin/ruby -Eutf-8
#
#= Ollama Chat

require "rubygems"
require "ollama-ai"
require "nkf"
require "natto"
require "duckduckgo"
require "wikipedia"
require "pp"

NATTO_LANG = "UTF-8" # EUC-JP

#LLMODEL = "gemma:2b"
#LLMODEL = "qwen2.5:1.5b"
#LLMODEL = "7shi/tanuki-dpo-v1.0:latest"
LLMODEL = "llama3.2:1b"

ROLL_SYSTEM = "system"
ROLL_ASSISTANT = "assistant"
ROLL_USEER = "user"

PER0_DEF = "Assistant"
PER1_DEF = "Visitor"


$llm_client = nil
$parser = nil

#=== main
def main()
  per0 = PER0_DEF
  per1 = PER1_DEF
  pasttalk = ""
  loop do
    if per1 == "Visitor"
      printf("%s あなた > ", Time::now.strftime("%T"))
    else
      printf("%s %s > ", Time::now.strftime("%T"), per1) 
    end
    getbuf = gets()
    if getbuf == nil
      printf("\n")
      break
    end
    per1_words = getbuf.strip
    wordscmd = per1_words[0..80].downcase.strip
    if wordscmd == ""
    elsif wordscmd == "bye"
      break
    elsif /you're\s+(\S+)/i =~ wordscmd
      per0 = $1
    elsif /i'm\s+(\S+)/i =~ wordscmd
      per1 = $1
    else
      time0 = Time::now
      per0_words = talk(per0, per1, per1_words, pasttalk)
      time = Time::now - time0
      printf("%s(%.1f) %s : %s\n", Time::now.strftime("%T"), time, per0, per0_words)
      pasttalk = sprintf("ユーザの「%s」としての発言: %s\n" \
        +             "assistantの「%s」としての発言: %s\n", \
        per1, per1_words, per0, per0_words)
    end
  end
end

#=== 回答を求める
def talk(per0, per1, per1_words, pasttalk)
  if $llm_client == nil
    $llm_client = Ollama::new(credentials: { address: "http://localhost:11434" },
                                  options: { server_sent_events: true })
  end
  system_content = ""
  # 語句の問い合わせ
  inquiry_results = inquiry(per1_words, [per0, per1])
  if inquiry_results
    system_content += inquiry_results
  end
  # 名前のの設定
  if per0 != PER0_DEF
    system_content += "#{ROLL_ASSISTANT} は #{per0} の役です。\n"
  end
  if per1 != PER1_DEF
    system_content += "#{ROLL_USEER} の名前は #{per1} です。\n"
  end
  # プロフィールの読み込み
  open("sall_init.txt") do |rh|
    system_content += rh.read + "\n"
  end
  # 過去の会話の追加
  system_content += pasttalk.to_s
  messages = []
  system_content.each_line do |line|
    messages << {"role": ROLL_SYSTEM, "content": line}
  end
  messages << {"role": ROLL_ASSISTANT, "content": "質問に簡潔に答えます。"}
  messages << {"role": ROLL_USEER, "content": per1_words}
  #puts messages
  chatdata = {
    model: LLMODEL,
    messages: messages
  }
  response = $llm_client.chat(chatdata)
  per0_words = get_content(response)
  if /^\(.+?として\)/ =~ per0_words
    per0_words = Regexp.last_match.post_match
  elsif /『(.+?)』/ =~ per0_words
    per0_words = $1
  end
  return per0_words
end

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

def inquiry(words, exclusions = [])
  inquiry_results = ""
  unless $wkpclient
    $wkpclient = Wikipedia::Client::new(Wikipedia::Configuration.new(domain: 'ja.wikipedia.org'))
  end
  unless $parser
    $parser = Natto::MeCab.new
  end
  words = NKF::nkf("-e", words) if NATTO_LANG != "UTF-8"
  nounarr = []
  noun = ""
  nouncont = false
  parsedtext = $parser.parse(words)
  parsedtext.each_line do |line|
    line = NKF::nkf("-w", line).scrub if NATTO_LANG != "UTF-8"
    if /^(.+?)\t名詞,(.+?),/ =~ line
      noun << $1
      kind = $2
      nouncont = true
    else
      nounarr << noun
      noun = ""
      nouncont = false
    end
  end
  if nouncont
    nounarr << noun
  end
  nounarr.each do |noun|
    unless exclusions.include?(noun)
      result = nil
      begin
        result = $wkpclient.find(noun)
      rescue
      end
      if result and result.summary
        inquiry_results << sprintf("%s : %s (Wikipedia)\n", result.title, result.summary)
      else
        results = DuckDuckGo::search(:query => noun)
        if results[0]
          inquiry_results << sprintf("%s : %s (DuckDuckGo)\n", results[0].title, results[0].description)
        end
      end
    end
  end
  return inquiry_results
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  main()
end

