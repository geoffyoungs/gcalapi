require "base_unit"

class TestCalendar1 < Test::Unit::TestCase
  include GoogleCalendar
  include CalendarTest

  def test_create_from_feed
    assert_instance_of(GoogleCalendar::Calendar, @cal)
  end

  def test_create_from_calendar_list
    list = GoogleCalendar::Calendar.calendars(@srv)
    assert_instance_of(Hash, list)
    list.each do |feed, cal| 
      assert_equal(cal.feed, feed)
      assert_instance_of(GoogleCalendar::Calendar, cal)
    end
  end

  #
  # THESE ACTUAL VALUES COULD BE DIFFERENT.
  #
  def test_calendar_attributes
    assert_equal("Calendar Test", @cal.title)
    assert_equal("Calendar Test Description", @cal.subtitle)
    assert_not_nil(@cal.name)
    assert_not_nil(@cal.updated)
    assert_equal(MAIL, @cal.email)
    assert_equal("Europe/London", @cal.timezone)
    assert_equal("Calendar Test Location", @cal.where)
  end

  def test_calendar_events_list
    st = Time.now
    en = st + 3600
    @srv.insert(FEED, event("t1", "e1", st, en))
    @srv.insert(FEED, event("t2", "e2", en, en + 3600))
    @cal.events.each do |event|
      assert_instance_of(GoogleCalendar::Event, event)
    end
  end

  def test_create_event
    ev = @cal.create_event
    assert_instance_of(GoogleCalendar::Event, ev)
  end

  def setup
    @srv = get_service
    @cal = GoogleCalendar::Calendar.new(@srv, FEED)
  end
end
