#!/usr/bin/env ruby

require 'smart-notebook'

# get and setup public ip for non-local server
servername = DRb::DRbTCPSocket.getservername
if not (servername=="::1" or servername=="127.0.0.1") then
  DRb.get_public_ip()
end

# start worker server
SmartNotebook::WorkerServer.new.auto_restart