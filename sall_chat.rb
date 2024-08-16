#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM

require "rubygems"
require "ollama-ai"

def main
  user_content = nil
  begin
    print ">>> "
    user_content = gets
    if user_content
      puts talk(user_content)
    end
    end while user_content
  puts
end

def talk(user_content)
  if $llm_client == nil
    $llm_client = Ollama.new(credentials: { address: "http://localhost:11434" },
                                            options: { server_sent_events: true })
  end

  system_content = <<EOT
光子は電磁相互作用を媒介するゲージ粒子で、ガンマ線の正体であり γ で表されることが多い。
ウィークボソンは弱い相互作用を媒介するゲージ粒子で、質量を持つ。
Wボソンは電荷±1をもつウィークボソンで、ベータ崩壊を起こすゲージ粒子である。W+, W−で表され、互いに反粒子の関係にある。
Zボソンは電荷をもたないウィークボソンで、ワインバーグ＝サラム理論により予言され、後に発見された。Z0 と書かれることもある。
グルーオンは強い相互作用を媒介するゲージ粒子で、カラーSU(3)の下で8種類存在する（8重項）。
XボソンとYボソンはジョージ＝グラショウ模型において導入される未発見のゲージ粒子である。
重力子（グラビトン）は重力を媒介する未発見のゲージ粒子で、スピン2のテンソル粒子と考えられている。
EOT

  messages = [
    { role: "assistant", content: system_content },
    { role: "user",      content: user_content },
  ]
  result = $llm_client.chat({ model: "gemma:2b", messages: messages })
  asst_content = get_content(result)
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

main if __FILE__ == $0
