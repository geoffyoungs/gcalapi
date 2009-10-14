require "googlecalendar/service"
require "googlecalendar/event"
require "rexml/document"

#
# = SUMMARY
# google calendar api for ruby
#
module GoogleCalendar
  class InvalidCalendarURL < StandardError; end #:nodoc: all

  #
  # = SUMMARY
  #   This class represents User's Calendar.
  # 
  # = How to get this class
  # * get calendar list
  # 
  #    srv = GoogleCalendar::Service.new(MAIL, PASS)
  #    cal_list = srv.calendars
  #
  #    cal_list is a hash of user's calendars.
  #      key: a calendar's editable feed url.
  #      value: calendar object.
  #
  # * create an instance from calendar's feed url
  #
  #    srv = GoogleCalendar::Service.new(MAIL, PASS)
  #    cal = Calendar.new(srv, FEED)
  #

  class Calendar

    attr_reader :feed

    # srv: GoogleCalendar::Service object
    # feed: Calendar's editable feed url(default value: user's default calendar)
    def initialize(srv, feed = DEFAULT_CALENDAR_FEED)
      @srv = srv
      @feed = feed
      @source = nil
    end

    #
    # REXML::Document object which represents calendar object
    #
    def source
      @source = get_data unless @source
      @source
    end

    #
    # send query to get events and returns an array of Event objects.
    # if any conditions are given, recent 25 entries are retrieved.
    # For detail, see Service#query
    #
    def events(conditions = {})
      ret = @srv.query(self.feed, conditions)
      raise InvalidCalendarURL unless ret.code == "200"
      REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |elem|
        elem.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
        elem.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
        elem.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
        entry = Event.new
        entry.srv = @srv
        entry.load_xml("<?xml version='1.0' encoding='UTF-8'?>#{elem.to_s}")
      end
    end

    #
    # creates a new Event instance which belongs to this clandar instance.
    #
    def create_event
      ev = Event.new
      ev.srv = @srv
      ev.feed = @feed
      ev
    end

    private

    def get_data
      #gets calendar data without events
      ret = @srv.query(@feed, "start-min" => Time.now, "start-max" => Time.now - 1)
      raise InvalidCalendarURL, ret.inspect unless ret.code == "200"
      REXML::Document.new(ret.body)
    end

    public
    
    DEFAULT_CALENDAR_FEED = "http://www.google.com/calendar/feeds/default/private/full"
    #
    # get user's calendar list.
    #
    def self.calendars(srv)
      ret = srv.calendar_list
      list = REXML::Document.new(ret.body)
      h = {}
      list.root.elements.each("entry/link") do |e|
        if e.attributes["rel"] == "alternate"
          feed = e.attributes["href"]
          h[feed] = Calendar.new(srv, feed)
        end
      end
      h
    end

    #
    # defines calendar's readonly attributes
    #
    ATTRIBUTES = {
      "updated" => ["updated"], 
      "title" => ["title"], 
      "subtitle" => ["subtitle"], 
      "name" => ["author/name"], 
      "email" => ["author/email"], 
      "timezone" => ["gCal:timezone", "value"],
      "where" => ["gd:where", "valueString"]}.each do |key, val|
      module_eval(
        "def #{key}; self.source.root.elements[\"#{val[0]}\"]." + 
        (val.length == 1 ? "text" : "attributes[\"#{val[1]}\"]") +
        "; end"
      )
    end

  end # class Calendar

end # module

