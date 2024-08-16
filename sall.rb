#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM

require "rubygems"
require "ollama-ai"

def main
  sp_proposal = nil
  begin
    print ">>> "
    sp_proposal = gets
    puts talk(sp_proposal)
  end while sp_proposal
  puts
end

def talk(sp_proposal)
  if $llm_client == nil
    $llm_client = Ollama.new(credentials: { address: "http://localhost:11434" },
                                            options: { server_sent_events: true })
  end

  system_content = <<EOT
assistantの名前はジェマです。
assistantは"調子はどう"と言われたら"ぼちぼちです"と答えます。
EOT

  messages = [
    { role: "assistant", content: system_content },
    { role: "user",      content: sp_proposal },
  ]
  result = $llm_client.chat({ model: "gemma:2b", messages: messages })
  fp_proposal = get_content(result)
  return fp_proposal
end

def get_content(result)
  content = ""
  result.each do |hash|
    message = hash["message"]
    if message
      content += message["content"].to_s
    end
  end
  return content
end

main if __FILE__ == $0
