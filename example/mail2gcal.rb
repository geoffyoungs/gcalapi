require "kconv"
require "yaml"
require "net/pop"
require "googlecalendar/calendar"

#
# This example shows how to create an event for Google Calendar from an e-mail.
#
# 1. the subject of the email must be 'gcal'.
#
# 2. write the mail body in yaml format. here is an example.
#      st: 2006-09-26 09:30:00
#      en: 2006-09-26 11:00:00
#      title: title of an event
#      desc: description of an event
#      where: location of an event
#
# 3. send the mail to your mail account.
#
# 4. execute this sample script.
#

POP_SERVER = "your pop server"
POP_PORT = 110
POP_ACCOUNT = "your account"
POP_PASSWORD = "your password"

GCAL_ACCOUNT = "your gmail account"
GCAL_PASSWORD = "your gmail password"
GCAL_FEED = "http://www.google.com/calendar/feeds/XXXXXXXXXXX@group.calendar.google.com/private/full"

TARGET_SUBJECT = "gcal"

# very simple e-mail parser.
class Mail
  attr_accessor :subject, :body
  def initialize(cont)
    self.subject = nil
    self.body = nil
    parse(cont)
  end

  SUBJECT = /^Subject: (.*)$/

  def parse(cont)
    head = true
    bd = []
    cont.each_line do |line|
      if head
        line.chomp!
        if line =~ SUBJECT
          self.subject = $1
        elsif line == ""
          head = false
        end
      else
        bd << line
      end
    end
    self.body = bd.join("")
  end
end

server = GoogleCalendar::Service.new(GCAL_ACCOUNT, GCAL_PASSWORD)
calendar = GoogleCalendar::Calendar.new(server, GCAL_FEED)

#
# * make an event of the calendar
# * set attributes of the event from email content.
# * update the event to the calendar.
#
def calendar.from_mail(mail)
  event = self.create_event
  yaml = YAML::load(mail.body)
  event.st = Time.parse(yaml["st"].to_s) if yaml.has_key?("st")
  event.en = Time.parse(yaml["en"].to_s) if yaml.has_key?("en")
  event.title = yaml["title"].toutf8 if yaml.has_key?("title")
  event.desc = yaml["desc"].toutf8 if yaml.has_key?("desc")
  event.where = yaml["where"].toutf8 if yaml.has_key?("where")
  event.allday = yaml["allday"] if yaml.has_key?("allday")
  event.save!
end

pop = Net::POP3.APOP(true).new(POP_SERVER, POP_PORT)
pop.start(POP_ACCOUNT, POP_PASSWORD)

if pop.mails.empty? then
  puts 'no mail.'
else
  i = 0
  pop.each_mail do |m|
    mail = Mail.new(m.pop)
    if mail.subject == TARGET_SUBJECT
      calendar.from_mail(mail)
      m.delete
      i += 1
    end
  end
  puts "#{i} mail(s) processed."
end
pop.finish
