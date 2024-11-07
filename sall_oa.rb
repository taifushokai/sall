#!/usr/bin/env -S ruby -Eutf-8
#
#= OpenAI Chat

require "openai"

$DBG = false # text mode debug
INIT_FILE  = "sall_init.txt"
LLMODEL = "gpt-4o"

ROLL_SYSTEM = "system"
ROLL_ASSISTANT = "assistant"
ROLL_USEER = "user"

ASSISTANT_DEF = "Assistant"
USER_DEF = "Visitor"

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
      assistant_sentence = talk(nil, assistant_name, user_name, user_sentence, pasttalk)
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
def talk(dummy, assistant_name, user_name, user_sentence, pasttalk)
  if $llm_client == nil
    $llm_client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end
  system_content = ""
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
  chatdata = {
    model: LLMODEL,
    messages: messages
  }
  response = $llm_client.chat(parameters: chatdata)
  assistant_sentence = response.dig("choices", 0, "message", "content")
  return assistant_sentence
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  main()
end

