module DRb
  attr_accessor :public_ip, :public_port
  module_function :public_ip, :public_ip=, :public_port, :public_port=

  def get_public_ip
    @public_ip = `curl http://checkip.amazonaws.com 2>/dev/null`.chomp
  end
  module_function :get_public_ip

  def uri
    current_server.uri.gsub(/[0-9]+$/,@public_port.to_s)
  end
  module_function :uri

  class DRbTCPSocket
    def self.getservername
      return DRb.public_ip if DRb.public_ip

      host = Socket::gethostname
      begin
        Socket::getaddrinfo(host, nil,
                            Socket::AF_UNSPEC,
                            Socket::SOCK_STREAM,
                            0,
                            Socket::AI_PASSIVE)[0][3]
      rescue
        'localhost'
      end
    end
  end
end
