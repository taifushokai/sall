#!/usr/bin/env -S ruby -Eutf-8
# encoding: utf-8
# small assistant by local LLM CGI
# index salltexts

require "fileutils"

TEXTS_DIR = "salltexts"
BEGINMARK = "---"
ENDMARK   = "^^^"

$index = nil

#=== main
def main()
  if ARGV[0] == "INDEX"
    index()
  else
    printf("ex) salltexts_util.rb INDEX\n")
  end
end

#=== インデックスの作成
def index()
  FileUtils::mkdir_p(TEXTS_DIR)
  $index = []
  Dir::glob("#{TEXTS_DIR}/**/*.txt") do |path|
    mode = 0 # keyword
    open(path) do |rh|
      rh.each_line do |line|
        line.strip!
        break if line == BEGINMARK or line == ENDMARK
        rpath = path.sub("#{TEXTS_DIR}/", "")
        $index << [line, rpath]
      end
    end
  end
  $index.uniq!
  open("#{TEXTS_DIR}/0.idx", "w") do |wh|
    $index.each do |keyword, rpath|
      wh.printf("%s\t%s\n", keyword, rpath)
    end
  end
end

def refer(word)
  if $index == nil
    readindex()
  end
  descrip = ""
  $index.each do |keyword, rpath|
    if word == keyword
      open("#{TEXTS_DIR}/#{rpath}") do |rh|
        rflag = false
        rh.each_line do |line|
          line.strip!
          if line == BEGINMARK
            flag = true
          elsif line == ENDMARK
            break
          else
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

def readindex()
  $index = []
  open("#{TEXTS_DIR}/0.idx") do |rh|
    rh.each_line do |line|
      $index << line.strip.split("\t", 2)
    end
  end
end

#= 直接呼ばれた場合は会話(CLI)を始める
if __FILE__ == $PROGRAM_NAME
  $DBG = true
  main()
end

