#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI

require "cgi"
require "./sall.rb"

def main
  cgi = CGI::new
  submit       = cgi["submit"]
  user_name    = cgi["user_name"]
  if user_name == ""
    user_name = "Visiter"
  end
  user_content = cgi["user_content"]
  if submit == "OK" && user_content != ""
    talk(user_name, user_content)
  elsif submit == "CLEAR"
    # どちらにしろ user_content は空になる
  end
  hist = get_hist(user_name)
  output(hist, user_name)
end

def output(hist, user_name)
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
        width: max-content;
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
      img {
        font-size: medium;
        margin-left: auto;
        margin-right: auto;
        vertical-align: auto;
        width: max-content;
        transition: 0.8s;
        border-radius: 0;
      }
      a {
        color: #101010;
        display: block;
        font-size: small;
        margin-left: auto;
        margin-right: auto;
        vertical-align: auto;
        width: max-content;
        transition: 0.8s;
        border-radius: 0;
      }
    </style>
  </head>
  <body style="text-align: center;">
    <form method="POST">
      <textarea name="ftalk" rows="24" readonly>#{hist}</textarea>
      あなたの名前 <input type="text"  name="user_name" value="#{user_name}">
      <br />
      <textarea name="stalk" rows="8"></textarea>
      &nbsp; &nbsp;
      <input type="submit" name="submit" value="OK" />
      &nbsp; &nbsp;
      <input type="submit" name="submit" value="CLEAR" />
    </form>
    <br />
  </body>
</html>
EOT
end

main

