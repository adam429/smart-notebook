#!/usr/bin/env ruby

require 'smart-notebook'

backend_pid = Process.fork do
  SmartNotebook::WorkerServer.new.auto_restart
end

sleep(0.1)

begin
  SmartNotebook::CLI.new.run
ensure
  Process.kill("INT", backend_pid)
end

