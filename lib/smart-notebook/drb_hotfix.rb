module DRb
  attr_accessor :public_host, :public_port
  module_function :public_host, :public_host=, :public_port, :public_port=

  def get_public_ip
    @public_host = `curl http://checkip.amazonaws.com 2>/dev/null`.chomp
  end
  module_function :get_public_ip

  def uri
    current_server.uri
  end

  class DRbTCPSocket
    def uri
      return @uri if DRb.public_host==nil and DRb.public_port==nil

      /\A(druby|drbssl):\/\/(.*?):(\d+)(\?(.*))?\z/ =~ @uri
      schema = $1
      host = $2
      port = $3.to_i
      option = $5

      host = DRb.public_host if DRb.public_host
      port = DRb.public_port if DRb.public_port

      uri =  "#{schema}://#{host}:#{port}"
      uri = uri + "?#{option}" if option

      return uri
    end
  end
  module_function :uri

  class DRbServer
    private

    def run
      Thread.start do
        begin
          AutoRetry.new.catch() do
            while main_loop
            end
          end
        ensure
          @protocol.close if @protocol
        end
      end
    end
  end
end
