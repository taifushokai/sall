#!/usr/local/bin/ruby -Eutf-8

th = Thread.new do
  system("sleep 6")
  #sleep 5
  #IO::popen("sleep 5") do |ph|
  #  puts ph.read
  #end
end

while th.status != false and th.status != nil
  printf("%s %s\n", Time::now.strftime("%T"), th.status)
  sleep 1
end

