Facter.add('galera_status') do
  setcode do
    begin
      require 'socket'
      Socket.tcp('localhost', 9200, connect_timeout: 1) {}
    rescue
      http_status = 'UNKNOWN'
    end
    if http_status == 'UNKNOWN'
      'UNKNOWN'
    else
      require 'net/http'
      uri = URI('http://localhost:9200/')
      Net::HTTP.get_response(uri).code
    end
  end
end
