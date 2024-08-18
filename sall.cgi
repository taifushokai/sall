#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI

require "cgi"
require "./sall.rb"

def main
  dbh = get_dbh()
  cgi = CGI::new
  submit       = cgi["submit"]
  user_name    = cgi["user_name"]
  if user_name == ""
    user_name = "Visiter"
  end
  user_content = cgi["user_content"]
  if submit == "OK" && user_content != ""
    (asst_content, user_name) = talk(dbh, user_name, user_content)
  elsif submit == "CLEAR"
    # どちらにしろ user_content は空になる
  end
  hist = ""
  get_hist(dbh, user_name, 20).each do |dir, content|
    if dir == "user"
      hist << sprintf("%s: %s\n", user_name, content.to_s.strip)
    else
      hist << sprintf("%s: %s\n", dir, content.to_s.strip)
    end
  end
  output(hist, user_name)
end

def output(hist, user_name)
  hist = CGI::escapeHTML(hist)
  user_name = CGI::escapeHTML(user_name)

  histbuf = hist.split("\n")
  eoa = histbuf.size - 1
  boa = eoa - 16 + 1 # なるべくtextarea に全体を表示させる
  boa = 0 if boa < 0
  hist = histbuf[boa .. eoa].join("\n")

  print <<EOT
Content-type: text/html

<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>small assistant by local LLM</title>
    <style>
      textarea {
        background: #f8f8f8;
        display: block;
        font-size: medium;
        margin-left: auto;
        margin-right: auto;
        vertical-align: auto;
        width: 100%;
        transition: 0.8s;
        border-radius: 0;
      }
      input[type="text"] {
        background: #ffe8c8;
        font-size: medium;
        margin-left: auto;
        margin-right: auto;
        vertical-align: auto;
        width: 120px;
        transition: 0.8s;
        border-radius: 0;
      }
      input[type="submit"] {
        background: #ffe8c8;
        font-size: medium;
        margin-left: auto;
        margin-right: auto;
        vertical-align: auto;
        width: 120px;
        transition: 0.8s;
        border-radius: 0;
      }
    </style>
  </head>
  <body style="text-align: left;">
    <form method="POST">
      話の流れ
      <br />
      <textarea name="hist" rows="24" readonly>#{hist}</textarea>
      あなたの名前 <input type="text"  name="user_name" value="#{user_name}">
      <br />
      あなたの話
      <br />
      <textarea name="user_content" rows="8"></textarea>
      <div style="text-align: center;">
      &nbsp; &nbsp;
      <input type="submit" name="submit" value="OK" />
      &nbsp; &nbsp;
      <input type="submit" name="submit" value="CLEAR" />
      </dev>
    </form>
    <br />
  </body>
</html>
EOT
end

main

