# sall
small assistant by local llm
(Processing target is Japanese)

## System Requirements
  OS is assumed to be AlmaLinux8
  The environment for running CGI is assumed to be Apache2.4
  Required libraries
    dnf install mecab
    dnf install mecab-ipadic

  Use Ollama and llama3.2:1b, which runs on it
    https://ollama.com/

  Use Ruby 3 as the programming language
  Required libraries
    gem install ollama-ai
    gem install natto
    gem install wikipedia-client
    gem install duckduckgo
    gem install sqlite3 -v '2.4.0'

    gem install ruby-openai(Example of using OpenAI's API)


## sall.cgi (Set in the cgi directory)
  (It is dialogues on the browser.)

## sall.rb
  ex) sall.rb
  (It is dialogues on the console.)

## salltexts_util.rb : Create texts index
  ex) salltexts_util.rb INDEX [texts_dir]
      (default texts_dir = salltexts)

## sallwords_util.rb : Inserting and extracting the contents of a sqlite3 database
  ex) sallwords_util.rb DUMP > dump.txt
  ex) sallwords_util.rb CLEAR
  ex) sallwords_util.rb INPUT < dump.txt

