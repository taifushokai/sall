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

LLMODEL = "gemma:2b"
ROLL_SYSTEM = "system"
ROLL_ASSISTANT = "assistant"
ROLL_USEER = "user"

PER0_DEF = "System"
PER1_DEF = "Visitor"

NATTO_LANG = "UTF-8" # EUC-JP

$llm_client = nil
$parser = nil
$hist = []

#=== main
def main()
  per0 = PER0_DEF
  per1 = PER1_DEF
  loop do
    if per1 == "Visitor"
      printf("あなた > ")
    else
      printf("%s > ", per1) 
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
      per0_words = talk(per0, per1, per1_words)
      printf("%s : %s\n", per0, per0_words)
    end
  end
end

#=== 回答を求める
def talk(per0, per1, per1_words)
  if $llm_client == nil
    $llm_client = Ollama::new(credentials: { address: "http://localhost:11434" },
                                  options: { server_sent_events: true })
  end
  system_content = ""
  suppl_content = suppl_wkp(per1_words, [per0, per1])
  if suppl_content
    system_content += suppl_content
  end
  open("sall_init.txt") do |rh|
    system_content += rh.read + "\n"
  end
  if per0 != PER0_DEF
    system_content += "#{ROLL_ASSISTANT} は #{per0} の役です。\n"
  end
  if per1 != PER1_DEF
    system_content += "#{ROLL_USEER} の名前は #{per1} です。\n"
  end
  messages = []
  system_content.each_line do |line|
    messages << {"role": ROLL_SYSTEM, "content": line}
  end
  $hist.each do |per1_hist, per0_hist|
    messages << {"role": ROLL_USEER, "content": per1_hist}
    messages << {"role": ROLL_ASSISTANT , "content": per0_hist}
  end
  messages << {"role": ROLL_ASSISTANT, "content": "質問に答えます。"}
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
  per0_hist = per0_words
  if per0 != PER0_DEF
    per0_hist = "(#{per0} として)" + per0_words
  end
  per1_hist = per1_words
  if per1 != PER1_DEF
    per1_hist = "(#{per1} として)" + per1_words
  end
  $hist << [per1_hist, per0_hist]
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

def suppl_wkp(words, exclusions = [])
  content = ""
  unless $wkpclient
    $wkpclient = Wikipedia::Client::new(Wikipedia::Configuration.new(domain: 'ja.wikipedia.org'))
  end
  unless $parser
    $parser = Natto::MeCab.new
  end
  words = NKF::nkf("-e", words) if NATTO_LANG != "UTF-8"
  parsedtext = $parser.parse(words)
  parsedtext.each_line do |line|
    line = NKF::nkf("-w", line).scrub if NATTO_LANG != "UTF-8"
    if /^(.+?)\t名詞,(一般|固有名詞|普通名詞|人名|組織名)/ =~ line
      noun = $1
      unless exclusions.include?(noun)
        result = $wkpclient.find(noun)
        if result.summary
          content = sprintf("%s : %s\n", result.title, result.summary)
        else
          results = DuckDuckGo::search(:query => noun)
          if results[0]
            content = sprintf("%s : %s\n", results[0].title, results[0].description)
          end
        end
      end
    end
  end
  return content
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  main()
end

