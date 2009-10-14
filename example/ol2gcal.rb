require "rubygems"
require "googlecalendar/calendar"
require "win32ole"
require "nkf"

# google calendar Feed URL
FEED_URL = "http://www.google.com/calendar/feeds/XXXXXXXXXXXXXXXX@group.calendar.google.com/private/full"
# email address
EMAIL = "XXXXXXXXXX@gmail.com"
# password
PASS = "XXXXXXX"

def each_event
  created = false
  ol = nil
  begin 
    ol = WIN32OLE.connect("Outlook.Application") 
  rescue 
    created = true
    ol = WIN32OLE.new("Outlook.Application") 
  end
  ns = ol.GetNameSpace("MAPI")
  folder = ns.GetDefaultFolder(9) #olFolderCalendar
  folder.Items.each do |event|
    GC.start
    yield event
  end
  ol.Quit if created
end

#proxy setting
GoogleCalendar::Service.proxy_addr="192.168.0.1"
GoogleCalendar::Service.proxy_port="8080"

@srv = GoogleCalendar::Service.new(EMAIL, PASS)
@cal = GoogleCalendar::Calendar.new(@srv, FEED_URL)

# Delete All Future Data Of Google Calendar
now = Time.now
@cal.events(:'start-min' => now, :orderby => "starttime").each do |ev| 
  p ev if $DEBUG
  ev.destroy! 
end

# Insert All Future Data Of Outlook
@nstr = now.strftime("%Y/%m/%d %H:%M:%S")
each_event do |oev|
  if oev.End > @nstr
    p oev.Subject if $DEBUG
    gev = @cal.create_event
    #NKF is used for japanese charcter code conversion
    gev.title = NKF.nkf("-w", oev.Subject)
    gev.where = NKF.nkf("-w", oev.Location)
    gev.st = Time.parse(oev.Start)
    gev.en = Time.parse(oev.End)
    gev.allday = oev.AllDayEvent
    gev.save!
  end 
end
