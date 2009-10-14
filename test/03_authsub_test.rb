require "base_unit"
require "rubygems"
require "mechanize"
require "logger"
require "cgi"
require "uri"
require "googlecalendar/service_auth_sub"
require "googlecalendar/auth_sub_util"

class TestService3 < Test::Unit::TestCase
  SAMPLE_URL = "http://zoriolab.info/test.html"
  attr_accessor :logger
  # get one-time token
  def test_get_onetime_token(use_session = false)
    # login google account
    agent = WWW::Mechanize.new do |a| a.log = logger end
    page = agent.get("https://www.google.com/accounts/Login")

    form = page.forms[0]
    form["Email"] = MAIL
    form["Passwd"] = PASS
    page = agent.submit(form)

    # get auth sub request url
    next_url = SAMPLE_URL
    use_secure = false
    request_url = GoogleCalendar::AuthSubUtil.build_request_url(
      next_url, GoogleCalendar::AuthSubUtil::CALENDAR_SCOPE, use_secure, use_session)
    query = "next=#{CGI.escape(next_url)}&scope=#{CGI.escape(GoogleCalendar::AuthSubUtil::CALENDAR_SCOPE)}&secure=#{use_secure ? "1" : "0"}&session=#{use_session ? "1" : "0"}"
    logger.debug(request_url)
    assert_equal(query, URI.parse(request_url).query)
  
    # get authsub request
    page = agent.get(request_url)
    form = page.forms[0]
    agent.redirect_ok = false
    page = agent.submit(form, form.buttons.first)

    #get one time token
    #
    #   In the real world, Google shows the link for your website. When the user clicks the link, you can
    #   get the one time token.
    #   But in this UNIT TEST, this process is omitted and the token is retrieved directly from google's response.
    #
    uri = URI.parse(page.links.first.href)
    params = CGI.parse(uri.query)
    expected = params["token"][0]
    logger.debug " token: #{expected}"
    one_time_token = GoogleCalendar::AuthSubUtil.get_one_time_token(page.links.first.href)
    assert_equal(expected, one_time_token)
    return one_time_token
  end
  
  def test_use_session_token
    one_time_token = test_get_onetime_token(true)
    session_token = nil
    srv = nil
    begin
      #get session token
      session_token = GoogleCalendar::AuthSubUtil.exchange_session_token(one_time_token)
      assert_not_nil(session_token)
      logger.debug(session_token)
      srv = GoogleCalendar::ServiceAuthSub.new(session_token)
      srv.logger = logger
      ret = srv.query(FEED, {})
      logger.debug(ret.body)
      assert_equal("200", ret.code)
      
      #do something
      yield(session_token, srv) if block_given?
    ensure
      #revoke token
      unless session_token.nil?
        GoogleCalendar::AuthSubUtil.revoke_session_token(session_token)
        ret = srv.query(FEED, {})
        logger.debug(ret)
        assert_equal("401", ret.code)
      end
    end
  end
  
  def test_query_with_session_token
    test_use_session_token do |token, srv|
      ret = srv.query(GoogleCalendar::Calendar::DEFAULT_CALENDAR_FEED, {})
      assert_equal("200", ret.code)
    end
  end
  
  def test_with_session_token
    test_use_session_token do |token, srv|
      cal = GoogleCalendar::Calendar.new(srv)
      event = cal.create_event
      event.desc = "desc"
      event.st = Time.now
      event.en = Time.now + 3600
      ret = event.save
      assert(ret)
      event.destroy!
    end
  end
  
  def test_session_info
    uri = URI.parse(SAMPLE_URL)
    test_use_session_token do |token, session|
      ret = GoogleCalendar::AuthSubUtil.token_info(token)
      expected = {"Secure" => "false", 
                  "Scope" => GoogleCalendar::AuthSubUtil::CALENDAR_SCOPE, 
                  "Target" => uri.host}
      expected.each do |k,v|
        assert(ret.key?(k))
        assert_equal(v, ret[k]) if ret.key?(k)
      end
    end
  end

  def test_calendar_list
    test_use_session_token do |token, srv|
      ret = srv.calendar_list
      assert_equal("200", ret.code, ret.body)
      xml = nil
      assert_nothing_raised { xml = REXML::Document.new(ret.body) }
      list = xml.root.elements.each("entry/link") {}.map {|e| e.attributes["href"] if e.attributes["rel"] == "alternate"}.compact
      assert(list.include?(FEED.gsub(/@/,"%40")))
    end
  end

  def test_ensure_revoked
    10.times do |n|
      test_use_session_token do |token, srv|
        ret = srv.query(FEED)
        assert_equal("200", ret.code)
      end
    end
  end

=begin  
  def test_use_onetime_token
    token = test_get_onetime_token(false)
    srv = GoogleCalendar::ServiceAuthSub.new(token)
    srv.logger = logger
    ret = srv.query(FEED)
    logger.debug(ret.body)
    assert_equal("200", ret.code)
    ret = srv.query(FEED)
    logger.debug(ret.body)
    assert_equal("401", ret.code)
  end
=end
  
  def setup
    @logger = Logger.new("authsub.log")
  end
end
