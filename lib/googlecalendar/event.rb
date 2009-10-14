require "rexml/document"
require "time"
require "nkf"

module GoogleCalendar
  class EventInsertFailed < StandardError; end #:nodoc: all
  class EventUpdateFailed < StandardError; end #:nodoc: all
  class EventDeleteFailed < StandardError; end #:nodoc: all
  class EventGetFailed < StandardError; end #:nodoc: all

  #
  # = Summary
  #   this class represents an event of a calendar.
  #
  # = How to use this class
  #
  # * MAIL: your gmail account.
  # * PASS: password for MAIL.
  # * FEED: a calendar's editable feed url.
  #   0. your default calendar's feed url is defined in Calendar::DEFAULT_CALENDAR_FEED. 
  #      To get other calendar's feed url, read below.
  #   1. click "Manage Calendars" in Google Calendar.
  #   2. select a calendar you want to edit.
  #   3. copy private address of XML.
  #   4. change the address's end into "/private/full". 
  #      If your calendar's private XML address is 
  #             "http://www.google.com/calendar/feeds/XXX@group.calendar.google.com/private-aaaaaa/basic", 
  #      the editable feed url is 
  #             "http://www.google.com/calendar/feeds/XXX@group.calendar.google.com/private/full".
  #   5. for detail, See http://code.google.com/apis/gdata/calendar.html#Visibility.
  #
  # == create new events
  #
  #    cal = Calendar.new(Service.new(MAIL, PASS), FEED)
  #    event = cal.create_event
  #    event.title = "event title"
  #    event.desc = "event description"
  #    event.where = "event location"
  #    event.st = Time.mktime(2006, 9, 21, 01, 0, 0)
  #    event.en = Time.mktime(2006, 9, 21, 03, 0, 0)
  #    event.save!
  #
  # == udpate existing events
  #
  #    cal = Calendar.new(Service.new(MAIL, PASS), FEED)
  #    event = cal.events[0]
  #    event.title = "event title"
  #    event.desc = "event description"
  #    event.where = "event location"
  #    event.st = Time.mktime(2006, 9, 21, 01, 0, 0)
  #    event.en = Time.mktime(2006, 9, 21, 03, 0, 0)
  #    event.save!
  #
  # == delete events
  #
  #    cal = Calendar.new(Service.new(MAIL, PASS), FEED)
  #    event = cal.events[0]
  #    event.destroy!
  #
  # == create all day events.
  #
  #    event = cal.create_event
  #    event.title = "1 days event"
  #    event.st = Time.mktime(2006, 9, 22)
  #    event.en = Time.mktime(2006, 9, 23)
  #    event.allday = true
  #    event.save!
  #
  #    event = cal.create_event
  #    event.title = "2 days event"
  #    event.st = Time.mktime(2006, 9, 22)
  #    event.en = Time.mktime(2006, 9, 24)
  #    event.allday = true
  #    event.save!
  #    
  # == get existint event
  #
  #    event = Event.get(FEED, Service.new(MAIL, PASS))
  #
  # = TODO
  #
  # * this class doesn't support recurring event.
  #
  require 'uri'

  class Event
    ATTRIBUTES_MAP = {
      "title" => { "element" => "title"}, 
      "desc" => { "element" => "content"},
      "where" => { "element" => "gd:where", "attribute" => "valueString" },
      "st" => { "element" => "gd:when", "attribute" => "startTime", "to_xml" => "time_to_str", "from_xml" => "str_to_time" },
      "en" => { "element" => "gd:when", "attribute" => "endTime", "to_xml" => "time_to_str", "from_xml" => "str_to_time" },
      "eventStatus" => { "element" => "gd:eventStatus", "attribute" => "value", "to_xml" => "frag_to_xml", "from_xml" => "frag_from_xml"  },
      "visibility" => { "element" => "gd:visibility", "attribute" => "value", "to_xml" => "frag_to_xml", "from_xml" => "frag_from_xml"  }

    }

    SKELTON = <<XML
<?xml version='1.0' encoding='UTF-8'?>
<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gd='http://schemas.google.com/g/2005'>
  <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/g/2005#event'></category>
  <title type='text'></title>
  <content type='text'></content>
  <gd:transparency value='http://schemas.google.com/g/2005#event.opaque'></gd:transparency>
  <gd:eventStatus value='http://schemas.google.com/g/2005#event.confirmed'></gd:eventStatus>
</entry>
XML

    attr_accessor :allday, :feed, :srv, :status, :where, :title, :desc, :st, :en, :xml, :eventStatus, :visibility

    def initialize()
      @xml = nil
      self.status = :new
    end

    def frag_to_xml(str)
      uri = URI.parse("http://schemas.google.com/g/2005")
      uri.fragment = str
      uri.to_s
    end
    def frag_from_xml(str)
      uri = URI.parse(str)
      uri.fragment
    end
    
    # load xml into this instance
    def load_xml(str)
      @xml = REXML::Document.new(str.to_s)
      xml_to_instance
      self
    end

    # same as save! If failed, this method returns false.
    def save
      do_without_exception(:save!)
    end

    # save this event into google calendar server. If failed, this method throws an Exception.
    def save!
      ret = nil
      case self.status
      when :new
        ret = @srv.insert(self.feed, self.to_s)
        raise EventInsertFailed, ret.body unless ret.code == "201"
      when :old
        ret = @srv.update(self.feed, self.to_s)
        raise EventUpdateFailed, ret.body unless ret.code == "200"
      when :deleted
        raise EventDeleteFailed, "already deleted"
      else
        raise StandardError, "invalid inner status"
      end
      load_xml(ret.body)
    end

    # same as destroy! If failed, this method returns false.
    def destroy
      do_without_exception(:destroy!)
    end

    # delete this event from google calendar server. If failed, this method throws an Exception.
    def destroy!
      ret = nil
      if self.status == :old
        ret = @srv.delete(self.feed, self.to_s) 
        raise EventDeleteFailed, "Not Deleted" unless ret.code == "200"
      else
        raise EventDeleteFailed, "Not Saved"
      end
      status = :deleted
    end

    # retuns this event's xml.
    def to_s
      @xml = REXML::Document.new(SKELTON) if self.status == :new
      instance_to_xml
      @xml.to_s
    end
  
    # get event from event feed
    def self.get(feed, srv)
      ret = srv.query(feed)
      raise EventGetFailed, ret.body unless ret.code == "200"
      evt = Event.new
      evt.srv = srv
      evt.load_xml(ret.body)
      evt
    end
    private

    def do_without_exception(method)
      ret = true
      begin
        self.send(method)
      rescue
        ret = false
      end
      ret
    end

    # set xml data to attributes of an instance
    def xml_to_instance
      ATTRIBUTES_MAP.each do |name, hash| 
        elem = @xml.root.elements[hash["element"]]
        unless elem.nil?
          val = (hash.has_key?("attribute") ? elem.attributes[hash["attribute"]] : elem.text)
          val = self.send(hash["from_xml"], val) if hash.has_key?("from_xml")
          self.send(name+"=", val)
        end
      end
      self.status = :old

      @xml.root.elements.each("link") do |link|
        @feed = link.attributes["href"] if link.attributes["rel"] == "edit"
      end
    end

    # set attributes of an instance into xml
    def instance_to_xml
      ATTRIBUTES_MAP.each do |name, hash|
        elem = @xml.root.elements[hash["element"]]
        elem = @xml.root.elements.add(hash["element"]) if elem.nil?
        val = self.send(name)
        val = self.send(hash["to_xml"], val) if hash.has_key?("to_xml")
        if hash.has_key?("attribute")
          elem.attributes[hash["attribute"]] = val
        else
          elem.text = val
        end
      end
    end

    # == Allday Event Bugs
    # When creating all day event, the format of gd:when startTime and gd:when endTime must 
    # be "yyyy-mm-ddZ" which represents UTC. otherwise the wrong data returns.
    # below is the test result. I used 3 countries' calendar. US, UK, and Japan.
    # And in each calendar, I created all day events in three types of date format.
    # A) yyyy-mm-dd
    # B) yyyy-mm-ddZ
    # C) yyyy-mm-dd+(-)hh:mm
    # only type B format always returns the correct data.
    # 
    # 1) US calendar (all type is OK)
    # A: input   start => 2006-09-18, end => 2006-09-19
    #    output  start => 2006-09-18, end => 2006-09-19
    # 
    # B: input   start => 2006-09-18Z,end => 2006-09-19Z
    #    output  start => 2006-09-18, end => 2006-09-19  
    #  
    # C: input   start => 2006-09-18-08:00,end => 2006-09-19-08:00
    #    output  start => 2006-09-18,      end => 2006-09-19  
    # 
    # 2) UK calenar (A returns wrong data. B and C is OK)
    # A: input   start => 2006-09-18, end => 2006-09-19
    #    output  start => 2006-09-17, end => 2006-09-18
    # 
    # B: input   start => 2006-09-18Z,end => 2006-09-19Z
    #    output  start => 2006-09-18, end => 2006-09-19  
    #  
    # C: input   start => 2006-09-18-00:00,end => 2006-09-19-00:00
    #    output  start => 2006-09-18,      end => 2006-09-19  
    # 
    # 3) Japan calendar (A and C returns wrong data. only B is OK)
    # A: input   start => 2006-09-18, end => 2006-09-19
    #    output  start => 2006-09-17, end => 2006-09-18
    # 
    # B: input   start => 2006-09-18Z,end => 2006-09-19Z
    #    output  start => 2006-09-18, end => 2006-09-19  
    #  
    # C: input   start => 2006-09-18+09:00,end => 2006-09-19+09:00
    #    output  start => 2006-09-17,      end => 2006-09-18
    # 
    # convert String to Time
    def str_to_time(st)
      ret = nil
      if st.is_a? Time then
        ret = st
      elsif st.is_a? String then 
        begin
          self.allday = false
          ret = Time.iso8601(st) 
        rescue 
          self.allday = true if st =~ /\d{4}-\d{2}-\d{2}/ # yyyy-mm-dd
          ret = Time.parse(st)
        end
      end
      ret
    end

    # returns string represents date or datetime 
    def time_to_str(dt)
      ret = nil
      if dt.nil?
        ret = ""
      else
        ret = dt.iso8601
        ret[10..-1] = "Z" if self.allday # yyyy-mm-ddZ
      end
      ret
    end
  end #class Event
end #module GoogleCalendar
