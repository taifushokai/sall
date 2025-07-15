#!/usr/bin/env -S ruby -Eutf-8
#
#= OpenAI Chat

require "openai"

$DBG = false # text mode debug
INIT_FILE  = "sall_init_oa.txt"
$LLMODEL = "gpt-4o"

module Roles
  SYSTEM = "system"
  ASSISTANT = "assistant"
  USER = "user"
end

module DefaultNames
  ASSISTANT = "Assistant"
  USER = "Visitor"
end

#=== main
def main()
  assistant_name = DefaultNames::ASSISTANT
  user_name = DefaultNames::USER
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
      printf("%s(%.1f sec, %s) %s : %s\n", Time::now.strftime("%T"), time, $LLMODEL, assistant_name, assistant_sentence)
      nowstr = Time::now.strftime("%F %T")
      pasttalk = sprintf(
        "時刻 %s のユーザの「%s」としての発言: %s\n" +
        "時刻 %s のassistantの「%s」としての発言: %s\n",
        nowstr, user_name, user_sentence,
        nowstr, assistant_name, assistant_sentence
      )
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
  if assistant_name != DefaultNames::ASSISTANT
    system_content += "#{Roles::ASSISTANT} は #{assistant_name} の役です。\n"
  end
  if user_name != DefaultNames::USER
    system_content += "#{Roles::USER} の名前は #{user_name} です。\n"
  end
  # プロフィールの読み込み
  setting = false
  buff = ""
  begin
    open(INIT_FILE) do |rh|
      rh.each_line do |line|
        if /^\^\^\^/ =~ line
          setting = true
        else
          if setting
            if /^llmodel:\s+(\S+)/ =~ line
              $LLMODEL = $1
            end
          else
            buff += line
          end
        end
      end
    end
  rescue => e
    puts "Init file read error: #{e.message}"
  end
  system_content += buff + "\n"
# 過去の会話の追加
  system_content += pasttalk.to_s
  # 現在時刻の追加
  system_content += sprintf("現在の時刻は %s\n", Time::now.strftime("%F %T"))
  messages = []
  system_content.each_line do |line|
    messages << {"role": Roles::SYSTEM, "content": line}
  end
  messages << {"role": Roles::ASSISTANT, "content": "質問に簡潔に答えます。"}
  messages << {"role": Roles::USER, "content": user_sentence}
  chatdata = {
    model: $LLMODEL,
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

