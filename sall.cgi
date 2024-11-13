#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI

require "cgi"
require "./sall.rb"

def main
  cgi = CGI::new
  submit             = cgi["submit"]
  user_name          = cgi["user_name"]
  user_name_new      = cgi["user_name_new"]
  user_sentence      = cgi["user_sentence"]
  assistant_name     = cgi["assistant_name"]
  assistant_name_new = cgi["assistant_name_new"]
  assistant_sentence = cgi["assistant_sentence"]
  user_sentence_new  = cgi["user_sentence_new"]
  nowstr = Time::now.strftime("%F %T")
  if user_sentence != "" or assistant_sentence != ""
    user_name = "Visiter" if user_name == ""
    assistant_name = "Assistant" if assistant_name == ""
    pasttalk = sprintf("時刻 %s のユーザの「%s」としての発言: %s\n" \
      +             "時刻 %s のassistantの「%s」としての発言: %s\n", \
      nowstr, nowstr, user_name, user_sentence, assistant_name, assistant_sentence)
  else
    pasttalk = ""
  end
  timestr = ""
  user_name = user_name_new
  user_name = "Visiter" if user_name == ""
  assistant_name = assistant_name_new
  assistant_name = "Assistant" if assistant_name == ""
  user_sentence = user_sentence_new
  if submit == "OK" && user_sentence != ""
    time0 = Time::now
    dbh = get_dbh()
    assistant_sentence, insize, outsize = talk(dbh, assistant_name, user_name, user_sentence, pasttalk)
    dbh.close
    time = Time::now - time0
    timestr = sprintf("%s (%.1f, in %d, out %d)", Time::now.strftime("%F %T"), time, insize, outsize)
  else # submit == "CLEAR"
    user_sentence = ""
    assistant_sentence = ""
  end
  output(user_name, user_sentence, assistant_name, assistant_sentence, timestr)
end

def output(user_name, user_sentence, assistant_name, assistant_sentence, timestr)
  user_name = CGI::escapeHTML(user_name.to_s)
  user_sentence = CGI::escapeHTML(user_sentence.to_s)
  assistant_name = CGI::escapeHTML(assistant_name.to_s)
  assistant_sentence = CGI::escapeHTML(assistant_sentence.to_s)
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
      <input type="hidden" name="user_name" value="#{user_name}" />
      あなたの名前 <input type="text"  name="user_name_new" value="#{user_name}" />
      <br />
      <textarea name="user_sentence" rows="2" readonly>#{user_sentence}</textarea>
      <br />
      <input type="hidden" name="assistant_name" value="#{assistant_name}" />
      相手の名前 <input type="text"  name="assistant_name_new" value="#{assistant_name}" />
      <br />
      <textarea name="assistant_sentence" rows="10" readonly>#{assistant_sentence}</textarea>
      #{timestr}
      <br />
      <br />
      入力欄
      <br />
      <textarea name="user_sentence_new" rows="2" style="background: #ffe8c8;"></textarea>
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

