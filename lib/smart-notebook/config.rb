module SmartNotebook

  class << self
    attr_accessor :store_history
    attr_accessor :worker_uri
    attr_accessor :cli_uri
    attr_accessor :drb_config
  end

  self.store_history = true
  self.worker_uri = "drbssl://:8429"
  self.cli_uri    = ["drbssl://:8430","drbssl://:8431","drbssl://:8432","drbssl://:8433"]
  self.drb_config = {:SSLCertName=>[["CN", "localhost"]]}

end