require "base_unit"

class TestService0 < Test::Unit::TestCase
  include GoogleCalendar
  include CalendarTest

  def test_invalid_auth
    s = GoogleCalendar::Service.new("invalid@example.com", "invalidpassword")
    s.logger = @srv.logger
    assert_raise(GoogleCalendar::AuthenticationFailed) do 
      s.calendar_list
    end
  end

  def test_calendar_list
    ret = @srv.calendar_list
    assert_equal("200", ret.code, ret.body)
    xml = nil
    assert_nothing_raised { xml = REXML::Document.new(ret.body) }
    list = xml.root.elements.each("entry/link") {}.map {|e| e.attributes["href"] if e.attributes["rel"] == "alternate"}.compact
    assert(list.include?(FEED.gsub(/@/,"%40")))
  end

  def test_insert_and_delete_event
    st = Time.now
    en = st + 3600
    ret = @srv.insert(FEED, event("title", "desc", st, en))
    assert_equal("201", ret.code, ret.body)
    xml = nil
    assert_nothing_raised { xml = REXML::Document.new(ret.body) }
    feed = get_feed_from_entry(xml)
    assert_not_nil(feed)
    assert_instance_of(String, feed)
    ret = @srv.delete(feed, ret.body)
    assert_equal("200", ret.code, ret.body)
  end

  def test_insert_and_update_event
    #insert
    st = Time.now
    en = st + 7200
    ret = @srv.insert(FEED, event("title1", "desc1", st, en))
    assert_equal("201", ret.code, ret.body)

    #update
    e1 = REXML::Document.new(ret.body)
    e1.root.elements["content"].text = "desc2"
    feed1 = get_feed_from_entry(e1)
    ret = @srv.update(feed1, e1.to_s)
    assert_equal("200", ret.code, ret.body)
    e2 = REXML::Document.new(ret.body)
    assert_equal("desc2", e2.root.elements["content"].text)
  end

  def test_query_without_range
    ret = @srv.query(FEED, {})
    entries = get_entry_from_query(ret)
    assert_equal(0, entries.length)

    ret = @srv.insert(FEED, event("t","d", Time.now, Time.now))
    assert_equal("201", ret.code)
    ret = @srv.query(FEED, {})
    entries = get_entry_from_query(ret)
    assert_equal(1, entries.length)
  end

  def test_query_start
    t1, t2, t3, t4 = prepare_data

    ret = @srv.query(FEED, :'start-min'=>t2, :'start-max'=>t3+1, :orderby=>'starttime')
    ens = get_entry_from_query(ret)
    assert_equal(2, ens.length)
    assert_equal("t3", ens[0].elements["title"].text)
    assert_equal("t2", ens[1].elements["title"].text)

    ret = @srv.query(FEED, :'start-min'=>t2, :'start-max'=>t3, :orderby=>'starttime')
    ens = get_entry_from_query(ret)
    assert_equal(1, ens.length)
    assert_equal("t2", ens[0].elements["title"].text)

    ret = @srv.query(FEED, :'start-min'=>t2, :orderby=>'starttime')
    ens = get_entry_from_query(ret)
    assert_equal(3, ens.length)
    assert_equal("t4", ens[0].elements["title"].text)
    assert_equal("t3", ens[1].elements["title"].text)
    assert_equal("t2", ens[2].elements["title"].text)

    ret = @srv.query(FEED, :'start-max'=>t3, :orderby=>'starttime')
    ens = get_entry_from_query(ret)
    assert_equal(2, ens.length)
    assert_equal("t2", ens[0].elements["title"].text)
    assert_equal("t1", ens[1].elements["title"].text)

    ret = @srv.query(FEED, :'start-max'=>t3+1, :orderby=>'starttime')
    ens = get_entry_from_query(ret)
    assert_equal(3, ens.length)
    assert_equal("t3", ens[0].elements["title"].text)
    assert_equal("t2", ens[1].elements["title"].text)
    assert_equal("t1", ens[2].elements["title"].text)

    ret = @srv.query(FEED, :orderby=>'starttime')
    ens = get_entry_from_query(ret)
    assert_equal(4, ens.length)
    assert_equal("t4", ens[0].elements["title"].text)
    assert_equal("t3", ens[1].elements["title"].text)
    assert_equal("t2", ens[2].elements["title"].text)
    assert_equal("t1", ens[3].elements["title"].text)
  end

  def test_query_q
    prepare_data

    ret = @srv.query(FEED, :q => 't1')
    ens = get_entry_from_query(ret)
    assert_equal(1, ens.length)
    assert_equal("t1", ens[0].elements["title"].text)

    ret = @srv.query(FEED, :q => 'd3')
    ens = get_entry_from_query(ret)
    assert_equal(1, ens.length)
    assert_equal("t3", ens[0].elements["title"].text)
  end

  def test_query_max_result
    prepare_data

    ret = @srv.query(FEED, "max-results" => 2, :orderby => "starttime")
    ens = get_entry_from_query(ret)
    assert_equal(2, ens.length)
    assert_equal("t4", ens[0].elements["title"].text)
    assert_equal("t3", ens[1].elements["title"].text)
  end

  def test_query_default_order
    prepare_data

    ret = @srv.query(FEED, {})
    ens = get_entry_from_query(ret)
    assert_equal(4, ens.length)
    assert_equal("t1", ens[0].elements["title"].text)
    assert_equal("t2", ens[1].elements["title"].text)
    assert_equal("t3", ens[2].elements["title"].text)
    assert_equal("t4", ens[3].elements["title"].text)
  end

  def setup
    @srv = get_service
    clear_all(@srv, FEED)
  end

  private 
  def prepare_data
    t1 = Time.parse("2006-09-12 01:00:00")
    t2 = t1 + 3600
    t3 = t2 + 3600
    t4 = t3 + 3600
    ret = @srv.insert(FEED, event("t4", "d4", t4, t4))
    assert_equal("201", ret.code, ret.body)
    sleep(2)
    ret = @srv.insert(FEED, event("t3", "d3", t3, t3))
    assert_equal("201", ret.code, ret.body)
    sleep(2)
    ret = @srv.insert(FEED, event("t2", "d2", t2, t2))
    assert_equal("201", ret.code, ret.body)
    sleep(2)
    ret = @srv.insert(FEED, event("t1", "d1", t1, t1))
    assert_equal("201", ret.code, ret.body)
    [t1, t2, t3, t4]
  end
end
