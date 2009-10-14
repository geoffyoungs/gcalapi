require "cgi"
require "uri"
require "net/http"
require "net/https"
require "open-uri"
require "nkf"
require "time"

Net::HTTP.version_1_2

module GoogleCalendar

  class AuthenticationFailed < StandardError; end #:nodoc: all

  #
  # This class interacts with google calendar service.
  #
  class ServiceBase
    # Server name to Authenticate
    AUTH_SERVER = "www.google.com"

    # URL to get calendar list
    CALENDAR_LIST_PATH = "http://www.google.com/calendar/feeds/default/allcalendars/full"
  
    # proxy server address
    @@proxy_addr = nil
    def self.proxy_addr
      @@proxy_addr
    end

    def self.proxy_addr=(addr)
      @@proxy_addr=addr
    end

    # proxy server port number
    @@proxy_port = nil
    def self.proxy_port
      @@proxy_port
    end

    def self.proxy_port=(port)
      @@proxy_port = port
    end

    # proxy server username
    @@proxy_user = nil
    def self.proxy_user
      @@proxy_user
    end

    def self.proxy_user=(user)
      @@proxy_user = user
    end

    # proxy server password
    @@proxy_pass = nil
    def self.proxy_pass
      @@proxy_pass
    end

    def self.proxy_pass=(pass)
      @@proxy_pass = pass
    end

    attr_accessor :logger

    #
    # get the list of user's calendars and returns http response object
    #
    def calendar_list
      logger.info("-- calendar list st --") if logger
      auth unless @auth
      uri = URI.parse(CALENDAR_LIST_PATH)
      res = do_get(uri, {})
      logger.info("-- calendar list en(#{res.message}) --") if logger
      res
    end

    alias :calendars :calendar_list

    #
    # send query for events of a calendar and returns http response object.
    # available condtions are 
    # * :q => query string
    # * :max-results => max contents count. (default: 25)
    # * :start-index => 1-based index of the first result to be retrieved
    # * :orderby => the order of retrieved data.
    # * :published-min => Bounds on the entry publication date(oldest)
    # * :published-max => Bounds on the entry publication date(newest)
    # * :updated-min => Bounds on the entry update date(oldest)
    # * :updated-max => Bounds on the entry update date(newest)
    # * :author => Entry author
    # and so on.
    # For detail, see http://code.google.com/apis/gdata/protocol.html#Queries
    #             and http://code.google.com/apis/calendar/reference.html#Parameters
    #
    def query(cal_url, conditions = nil)
      logger.info("-- query st --") if logger
      auth unless @auth
      uri = URI.parse(cal_url)
      uri.query = conditions.map do |key, val|
        "#{key}=#{URI.escape(val.kind_of?(Time) ? val.getutc.iso8601 : val.to_s)}"
      end.join("&") unless conditions.nil?
      res = do_get(uri, {})
      logger.info("-- query en (#{res.message}) --") if logger
      res
    end
  
    #
    # delete an event.
    #
    def delete(feed, event)
      logger.info("-- delete st --") if logger
      auth unless @auth
      uri = URI.parse(feed)
      res = do_post(uri, 
              {"X-HTTP-Method-Override" => "DELETE", 
               "Content-Type" => "application/atom+xml",
               "Content-Length" => event.length.to_s}, event)
      logger.info("-- delete en (#{res.message}) --") if logger
      res
    end
    
    #
    # insert an event
    #
    def insert(feed, event)
      logger.info("-- insert st --") if logger
      auth unless @auth
      uri = URI.parse(feed)
      res = do_post(uri, 
              {"Content-Type" => "application/atom+xml",
               "Content-Length" => event.length.to_s}, event)
      logger.info("-- insert en (#{res.message}) --") if logger
      res
    end
  
    #
    # update an event.
    #
    def update(feed, event)
      logger.info("-- update st --") if logger
      auth unless @auth
      uri = URI.parse(feed)
      res = do_post(uri, 
              {"X-HTTP-Method-Override" => "PUT", 
               "Content-Type" => "application/atom+xml",
               "Content-Length" => event.length.to_s}, event)
      logger.info("-- update en (#{res.message}) --") if logger
      res
    end
    
    private 
  
    # authencate
    def auth
      raise AuthenticationFailed
    end
    
    def do_post(uri, header, content)
      logger.debug("POST:" + uri.to_s) if logger
      res = nil
      try_http(uri, header, content) do |http,path,head,args|
        cont = args[0]
        res = http.post(path, cont, head) 
      end
      res
    end
    
    def do_get(uri, header)
      logger.debug("GET:" + uri.to_s) if logger
      res = nil
      try_http(uri, header) do |http,path,head| 
        res = http.get(path, head) 
      end
      res
    end
    
    def try_http(uri, header, *args)
      res = nil
      add_authorize_header(header)
      Net::HTTP.start(uri.host, uri.port, @@proxy_addr, @@proxy_port, @@proxy_user, @@proxy_pass) do |http|
        header["Cookie"] = @cookie if @cookie
        res = yield(http, path_with_authorized_query(uri), header, args)
        logger.debug(res) if logger
        if res.code == "302"
          ck = sess = nil
          ck = res["set-cookie"] if res.key?("set-cookie")
          uri = URI.parse(res["location"]) if res.key?("location")
          if uri && uri.query
            qr = CGI.parse(uri.query)
            sess = qr["gsessionid"][0] if qr.key?("gsessionid")
          end
          if ck && sess
            logger.debug("cookie: #{ck}, gsessionid:#{sess}") if logger
            header["Cookie"] = @cookie = ck
            @session = sess
            res = yield(http, path_with_authorized_query(uri), header, args)
            logger.debug(res) if logger
          else
            logger.fatal res.body.gsub(/\n/, ' ') if logger
          end
        end
      end
      res
    end
    
    def path_with_authorized_query(uri)
      query = CGI.parse(uri.query.nil? ? "" : uri.query)
      query["gsessionid"] = [@session] if @session
      qs = query.map do |k,v| "#{CGI.escape(k)}=#{CGI.escape(v[0])}" end.join("&")
      qs.empty? ? uri.path : "#{uri.path}?#{qs}"
    end
  end # class ServiceBase
end # module
