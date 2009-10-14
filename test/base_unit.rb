$:.unshift(File.dirname(__FILE__) + '/../lib')

require "parameters"
require 'test/unit'
require "googlecalendar/calendar"
require "logger"

module CalendarTest
  include GoogleCalendar
  def get_service
    Service.proxy_addr = PROXY_ADDR if defined?(PROXY_ADDR)
    Service.proxy_port = PROXY_PORT if defined?(PROXY_PORT)
    srv = Service.new(MAIL, PASS)
    srv.logger = Logger.new("testlog.log")
    srv.logger.level = Logger::DEBUG
    assert_instance_of(Service, srv)
    srv.send("auth")
    assert_not_nil(srv.instance_eval("@auth"))
    srv
  end

  def event(title, desc, st, en)
    ret = <<XML
<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gd='http://schemas.google.com/g/2005'>
<category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/g/2005#event'></category>
<title type='text'>#{title}</title>
<content type='text'>#{desc}</content>
<gd:transparency value='http://schemas.google.com/g/2005#event.opaque'></gd:transparency>
<gd:eventStatus value='http://schemas.google.com/g/2005#event.confirmed'></gd:eventStatus>
<gd:where valueString=''></gd:where>
<gd:when startTime='#{st.iso8601}' endTime='#{en.iso8601}'></gd:when>
</entry>
XML
    ret
  end
  
  def clear_all(srv, feed)
    cal = Calendar.new(srv, feed)
    cal.events.each do |elem| elem.destroy end
  end

  def get_entry_from_query(ret)
    assert_equal("200", ret.code)
    xml = nil
    assert_nothing_raised { xml = REXML::Document.new(ret.body) }
    entries = xml.root.elements.each("entry"){}
  end

  def get_feed_from_entry(xmldoc)
    xmldoc.root.elements.each("link"){}.map{|e| e.attributes["href"] if e.attributes["rel"] == "edit"}.compact[0]
  end
end
