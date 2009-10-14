require "cgi"
require "uri"
require "net/http"
require "net/https"

module GoogleCalendar

  #
  # Exception about AuthSub
  #
  class AuthSubFailed < StandardError
    attr_accessor :http_response
    def initialize(res)
      http_response = res
    end
  end
  #
  # = Summary
  # Helper class for AuthSub authentication.
  # For detail, see http://code.google.com/apis/accounts/AuthForWebApps.html
  # Currently, this class is available for only unregistered website.
  #
  # = How to use this class
  #
  # == Show AuthSubRequest link to a user.
  #
  #    First, you need to show your user an anchor to the AuthSubRequest. The user can get authentication token 
  #    in the page. And the user will redirect back to your Website with authentication token.
  #
  #    request_url = AuthSubUtil.build_request_url(next_url, AuthSubUtil::CALENDAR_SCOPE, use_secure, use_session)
  #
  # == Get token from redirected URL.
  #
  #    The redirected URL string contains one time session token. You can get the token using get_one_time_token method.
  #
  #    token = AuthSubUtil.get_one_time_token(urlstr)
  #
  # == Get session token.
  #
  #    You will get an one time token above process. Then you can get longtime living sessin token.
  #
  #    session = AuthSubUtil.exchange_session_token(one_time_token)
  #
  # == make a ServiceAuthSub instance instead of Service.
  #
  #    srv = GoogleCalendar::ServiceAuthSub.new(session_token)
  #
  # == Revoke session token.
  #
  #    Google limits the number of session token per user. So you should revoke the session token after using.
  #
  #    AuthSubUtil.revoke_session_token(session_token)
  #
  class AuthSubUtil
    REQUEST_URL = "https://www.google.com/accounts/AuthSubRequest"
    SESSION_URL = "https://www.google.com/accounts/AuthSubSessionToken"
    REVOKE_URL  = "https://www.google.com/accounts/AuthSubRevokeToken"
    INFO_URL = "https://www.google.com/accounts/AuthSubTokenInfo"

    CALENDAR_SCOPE = "http://www.google.com/calendar/feeds/"
    
    #
    # Build url for AuthSubRequest.
    # http://code.google.com/apis/accounts/AuthForWebApps.html#AuthSubRequest
    # Currently, secure token is not implemented.
    #
    def self.build_request_url(next_url, scope, use_secure, use_session)
      hq = [["next", next_url], 
            ["scope", CALENDAR_SCOPE], 
            ["secure", use_secure ? "1" : "0"], 
            ["session", use_session ? "1" : "0"]]
      query = hq.map do |elem| "#{elem[0]}=#{CGI.escape(elem[1])}" end.join("&")
      return "#{REQUEST_URL}?#{query}"
    end
    
    #
    # Get authentication token from the redirected url.
    # When the AuthSubRequest is accepted, the edirected URL string (specified in next_url parameter of 
    # build_reque4st_url method) contains authentication token. This method retrieves the token from url string.
    # This token is for a single use only. To get long-lived token, use exchange_session_token method.
    #
    def self.get_one_time_token(url_str)
      uri = URI.parse(url_str)
      params = CGI.parse(uri.query)
      throw AuthSubFailed, "Token is not found" unless params.key?("token")
      return params["token"][0]
    end
    
    #
    # Get session token. 
    # The authentication token you get by calling AuthSubRequest is available only once. 
    # To get long-lived token, use this.
    # For detail, see http://code.google.com/apis/accounts/AuthForWebApps.html#AuthSubSessionToken
    #
    def self.exchange_session_token(one_time_token)
      res = do_get_with_ssl(SESSION_URL, one_time_token)
      throw AuthSubFailed.new(res) unless res.code == "200"
      session_token = nil
      if /Token=(.*)$/ =~ res.body 
        session_token = $1.to_s 
      else
        throw AuthSubFailed.new(res), "Token not found"
      end
      return session_token
    end
    
    #
    # You can get session token by calling exchange_session_token method. Session token will remain
    # until you revoke.
    # For detail, http://code.google.com/apis/accounts/AuthForWebApps.html#AuthSubRevokeToken
    #
    def self.revoke_session_token(session_token)
      res = do_get_with_ssl(REVOKE_URL, session_token)
      throw AuthSubFailed.new(res) unless res.code == "200"
      return res
    end
    
    
    def self.token_info(session_token)
      res = do_get_with_ssl(INFO_URL, session_token)
      throw AuthSubFailed.new(res), res.to_s unless res.code == "200"
      ret = {}
      res.body.each_line do |line|
        ret[$1] = $2  if line =~ /^([^=]+)=(.+)$/
      end
      return ret
    end
    
    private 
    
    def self.do_get_with_ssl(str_uri, token)
      res = nil
      uri = URI.parse(str_uri)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      https.start do |http|
        res = http.get(uri.path, {"Authorization" => "AuthSub token=\"#{token}\""})
      end
      return res
    end
  end # AuthSubUtil
end # GoogleCalendar
