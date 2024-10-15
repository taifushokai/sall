#!/usr/local/bin/ruby -Eutf-8
#
#= Ollama Chat

require "rubygems"
require "ollama-ai"
require "natto"
require "pp"

LLMODEL = "gemma:2b"
PER0_DEF = "System"
PER1_DEF = "Visitor"
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
  open("sall_init.txt") do |rh|
    system_content = rh.read + "\n"
  end
  if per0 != PER0_DEF
    system_content += "assistant は #{per0} の役です。\n"
  end
  if per1 != PER1_DEF
    system_content += "user の名前は #{per1} です。\n"
  end
  system_content += analyze(per1_words)
  messages = [{"role": "system", "content": system_content}]
  $hist.each do |per1_hist, per0_hist|
    messages << {"role": "user", "content": per1_hist}
    messages << {"role": "assistant" , "content": per0_hist}
  end
  messages << {"role": "user", "content": per1_words}
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
    if message and message["role"] == "assistant"
      content += message["content"].to_s
    end
  end
  return content
end

def analyze(words)
  content = ""
  unless $parser
    $parser = Natto::MeCab.new
  end
  parsedtext = $parser.parse(words)
  pp parsedtext
  puts parsedtext
  return content
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  main()
end

