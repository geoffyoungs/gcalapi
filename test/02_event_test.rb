require "base_unit"

class TestCalendar2 < Test::Unit::TestCase
  include GoogleCalendar
  include CalendarTest

  def test_create
    st = Time.now
    en = st + 3600
    event = @cal.create_event
    event.title = "title"
    event.desc = "desc"
    event.st = st
    event.en = en
    ret = event.save
    assert(ret)
    evs = @cal.events
    assert_equal(1, evs.length)
    assert_same_event(event, evs[0])

    event.desc = "updated"
    assert(event.save)
    evs = @cal.events
    assert_equal(1, evs.length)
    assert_same_event(event, evs[0])
  end

  def test_update
    @srv.insert(FEED, event("test1", "desc1", Time.now, Time.now + 3600))
    ev1 = @cal.events[0]
    ev1.desc = "desc2"
    #assert(ev1.save)
    ev1.save!
    ev2 = @cal.events[0]
    assert_same_event(ev1, ev2)
    assert_equal("desc2", ev2.desc)
  end

  def test_delete
    @srv.insert(FEED, event("test1", "desc1", Time.now, Time.now + 3600))
    ev1 = @cal.events[0]
    #assert(ev1.destroy)
    ev1.destroy!
    assert_equal(0, @cal.events.length)
  end
  
  def test_get_event
    ev = @cal.create_event
    ev.title = "title"
    ev.desc = "desc"
    ev.st = Time.now
    ev.en = Time.now + 3600
    ev.save!
    
    #@srv.logger.level = Logger::DEBUG
    e2 = Event.get(ev.feed, @srv)
    assert_same_event(ev, e2)
    
    e2.desc = "changed"
    e2.save!
    assert_equal("changed", e2.desc)
    
    e3 = Event.get(ev.feed, @srv)
    assert_same_event(e2, e3)
  end
  
  def test_get_event_fail
    #@srv.logger.level = Logger::DEBUG
    assert_raise(GoogleCalendar::EventGetFailed) do 
      Event.get(GoogleCalendar::Calendar::DEFAULT_CALENDAR_FEED + "/XXXXXXXXXXXXXXXXXXXXX", @srv)
    end
  end
  
  def setup
    @srv = get_service
    clear_all(@srv, FEED)
    @cal = GoogleCalendar::Calendar.new(@srv, FEED)
  end

  private

  def assert_same_event(ev1, ev2)
    ["title", "desc", "st", "en"].each do |elem|
      assert_equal(ev1.send(elem), ev2.send(elem))
    end
  end
end
