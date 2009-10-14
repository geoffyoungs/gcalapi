require "rubygems"
require "mechanize"
require "kconv"
require "gcalapi"
require "logger"

MIXI_EMAIL = "XXXXXXXX@hotmail.com"
MIXI_PASS = "ZZZZZZZZZZZZZZZZZ"

GCAL_FEED = "http://www.google.com/calendar/feeds/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX@group.calendar.google.com/private/full"
GCAL_MAIL = "XXXXXXXXXXXX@gmail.com"
GCAL_PASS = "XXXXXXXXXXXXXX"

now = Time.now
logger = Logger.new("mixi.log")
logger.level = Logger::INFO

# login to mixi and get this month's calendar.

agent = WWW::Mechanize.new do |a| a.log = logger end
page = agent.get('https://mixi.jp')
form = page.forms[0]
form.fields.find do |f| f.name == "email" end.value = MIXI_EMAIL
form.fields.find do |f| f.name == "password" end.value = MIXI_PASS
page = agent.submit(form, form.buttons.first)

if /url=([^"]+)"/ =~ page.body 
  link = 'http://mixi.jp' + $1.to_s
  agent.get(link)
end
page = agent.get("http://mixi.jp/show_calendar.pl?year=#{now.year}&month=#{now.mon}")



# parse calendar html and retrieve event data.
result = []

root = Hpricot(page.body)
ts = (root/"table[@width='670']")# this condition depends on the structure of the page.
return if ts.length < 3

table = ts[2]
table.search(:td).each do |td|
  f = td.children[0]
  day = f.inner_text.to_i
  if day > 0
    td.search(:a).each do |a| 
      if a["href"] != "javascript:void(0)" #exclude schedule add button
        a["href"] = "http://mixi.jp/#{a['href']}" 
        logger.info "#{day}: #{a.inner_text.toutf8}"
        result << {:day => day, :desc => a}
      end
    end
  end
end


# insert event data into google calendar.

srv = GoogleCalendar::Service.new(GCAL_MAIL, GCAL_PASS)
cal = GoogleCalendar::Calendar.new(srv, GCAL_FEED)

st = Time.mktime(now.year, now.mon, 1)
if st.mon == 12 
  en = Time.mktime(now.year + 1, 1, 1)
else
  en = Time.mktime(now.year, now.mon + 1, 1)
end

# delete **ALL** EVENTS of google calendar 
cal.events(:'start-min' => st, 
           :'start-max' => en, 
           :'max-results' => 100).each do |event| 
  event.destroy! 
end

# insert event data.
result.each do |mixi|
  day = Time.mktime(now.year, now.mon, mixi[:day])
  event = cal.create_event
  event.title = mixi[:desc].inner_text.toutf8
  event.desc = mixi[:desc].to_html.toutf8
  event.st = day
  event.en = day + 86400 # next day
  event.allday = true
  event.save!
  logger.debug(event.to_s)
end
