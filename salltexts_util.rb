#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI
# index salltexts

require "fileutils"

$TEXTS_DIR = "salltexts"

SALLTEXTMARK = "^-^"
BEGINMARK = "==="
ENDMARK   = "^^^"

$index = nil

#=== main
def main()
  if ARGV[0] == "INDEX"
    index_texts(ARGV[1])
  else
    printf("ex) salltexts_util.rb INDEX [texts_dir]\n")
  end
end

#=== インデックスの作成
def index_texts(texts_dir = nil)
  init_texts(texts_dir)
  FileUtils::mkdir_p($TEXTS_DIR)
  $index = []
  Dir::glob("#{$TEXTS_DIR}/**/*.txt") do |path|
    open(path) do |rh|
      head = rh.gets.strip
      break if head != SALLTEXTMARK
      rpath = path.sub("#{$TEXTS_DIR}/", "")
      rh.each_line do |line|
        line.strip!
        if /\A#{Regexp::quote(BEGINMARK)}/ =~ line
          Regexp.last_match.post_match.to_s.split("|").each do |keyword|
            keyword.strip!
            $index << [keyword, rpath]
          end
          break
        end
      end
    end
  end
  $index.uniq!
  open("#{$TEXTS_DIR}/0.idx", "w") do |wh|
    $index.each do |keyword, rpath|
      wh.printf("%s\t%s\n", keyword, rpath)
    end
  end
end

#=== 初期設定
def init_texts(texts_dir)
  if texts_dir
    $TEXTS_DIR = texts_dir
  end
end

def insert_text(words, descrip)
  wordsarr = []
  words.to_s.split("|").each do |word|
    wordsarr << word.strip
  end
  filename = sprintf("%s_%03d.txt", Time::now.strftime("%Y%m%d_%H%M%S"), rand(1000))
  open("#{$TEXTS_DIR}/#{filename}", "w") do |rh|
    rh.printf("%s\n",   SALLTEXTMARK)
    rh.printf("%s%s\n", BEGINMARK, wordsarr.join("|"))
    rh.printf("%s\n",   descrip)
    rh.printf("%s\n",   ENDMARK)
  end
  index_texts()
end

def list_texts()
  list = []
  open("#{$TEXTS_DIR}/0.idx") do |rh|
    rh.each_line do |line|
      list << line.strip.split("\t", 2)[0]
    end
  end
  return list.sort.join("\n")
end

def refer_text(word)
  if $index == nil
    read_textindex()
  end
  descrip = ""
  $index.each do |keyword, rpath|
    if word.casecmp(keyword).zero?
      open("#{$TEXTS_DIR}/#{rpath}") do |rh|
        rflag = false
        rh.each_line do |line|
          line.strip!
          if    /\A#{Regexp::quote(BEGINMARK)}/ =~ line
            rflag = true
          elsif /\A#{Regexp::quote(ENDMARK)}/ =~ line
            break
          elsif rflag
            descrip << line
          end
        end
      end
      descrip << "\n"
    end
  end
  if descrip == ""
    descrip = nil
  end
  return descrip
end

def read_textindex()
  $index = []
  open("#{$TEXTS_DIR}/0.idx") do |rh|
    rh.each_line do |line|
      $index << line.strip.split("\t", 2)
    end
  end
end

#= 直接呼ばれた場合はコマンド
if __FILE__ == $PROGRAM_NAME
  $DBG = true
  main()
end

