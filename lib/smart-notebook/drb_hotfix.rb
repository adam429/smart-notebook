module DRb
  attr_accessor :public_ip
  module_function :public_ip, :public_ip=

  def get_public_ip
    return `curl http://checkip.amazonaws.com`.chomp
  end

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
