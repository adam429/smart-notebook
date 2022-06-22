#!/usr/bin/env ruby

require 'smart-notebook'
require 'optparse'

begin
  backend_pid = Process.fork do
    SmartNotebook::WorkerServer.new.auto_restart
  end
rescue =>e
  puts e.inspect
  puts e.backtrace
end

sleep(0.1)


options = {}
OptionParser.new do |parser|
  parser.on('-p','--public URI',"public URI for expose to external network")
end.parse!(into: options)

if options[:public] then
  DRb.public_host, DRb.public_port = options[:public].split(":")
end


puts "public: #{DRb.public_host}:#{DRb.public_port}" if DRb.public_host or DRb.public_port



begin
  SmartNotebook::CLI.new.run
ensure
  Process.kill("TERM", backend_pid)
end

