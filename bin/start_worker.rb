#!/usr/bin/env ruby

require 'smart-notebook'
require 'optparse'

# get and setup public ip for non-local server
servername = DRb::DRbTCPSocket.getservername
if not (servername=="::1" or servername=="127.0.0.1") then
  DRb.get_public_ip()
end

options = {}
OptionParser.new do |parser|
  parser.on('-p','--public URI',"public URI for expose to external network")
end.parse!(into: options)

if options[:public] then
  DRb.public_host, DRb.public_port = options[:public].split(":")
end


puts "public: #{DRb.public_host}:#{DRb.public_port}" if DRb.public_host or DRb.public_port
# start worker server
SmartNotebook::WorkerServer.new.auto_restart