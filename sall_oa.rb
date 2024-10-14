#!/usr/local/bin/ruby -Eutf-8
#
#= OpenAI Chat

require "openai"
require "pp"

LLMODEL = "gpt-4o"
PER0_DEF = "System"
PER1_DEF = "Visitor"
$llm_client = nil
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
    per1_words = gets().to_s.strip
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
    $llm_client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end
  system_content = ""
  open("sall_init.txt") do |rh|
    system_content = rh.read
  end
  if per0 != PER0_DEF
    system_content += "\n assistant は #{per0} の役です。"
  end
  if per1 != PER1_DEF
    system_content += "\n user の名前は #{per1} です。"
  end
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
  response = $llm_client.chat(parameters: chatdata)
  per0_words = response.dig("choices", 0, "message", "content")
  if /『(.+?)』/ =~ per0_words
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

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  main()
end

