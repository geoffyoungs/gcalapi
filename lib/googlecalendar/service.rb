require "googlecalendar/service_base"

module GoogleCalendar
  #
  # This class interacts with google calendar service. 
  # If you want to use ClientLogin for authentication, use this class.
  # If you want to use AuthSub, use ServiceAuthSub. 
  #
  class Service < ServiceBase

    # Server Path to authenticate
    AUTH_PATH = "/accounts/ClientLogin"

    def initialize(email, pass)
      @email = email
      @pass = pass
      @session = nil
      @cookie = nil
      @auth = nil
    end 

  private 
    def auth
      https = Net::HTTP.new(AUTH_SERVER, 443, @@proxy_addr, @@proxy_port, @@proxy_user, @@proxy_pass)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      head = {'Content-Type' => 'application/x-www-form-urlencoded'}
      logger.info "-- auth st --" if logger
      https.start do |w|
        res = w.post(AUTH_PATH, "Email=#{@email}&Passwd=#{CGI.escape(@pass)}&source=company-app-1&service=cl", head)
        logger.debug res if logger
        if res.body =~ /Auth=(.+)/
          @auth = $1 
        else
          if logger
            logger.fatal(res)
            logger.fatal(res.body)
          end
          raise AuthenticationFailed
        end
      end
      logger.info "-- auth en --" if logger
    end
  
    def add_authorize_header(header)
      header["Authorization"] = "GoogleLogin auth=#{@auth}"
    end
  end # Service
end # GoogleCalendar
