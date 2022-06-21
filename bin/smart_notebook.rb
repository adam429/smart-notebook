#!/usr/bin/env ruby

require 'smart-notebook'

begin
  backend_pid = Process.fork do
    SmartNotebook::WorkerServer.new.auto_restart
  end
rescue =>e
  puts e.inspect
  puts e.backtrace
end

sleep(0.1)

begin
  SmartNotebook::CLI.new.run
ensure
  Process.kill("INT", backend_pid)
end

