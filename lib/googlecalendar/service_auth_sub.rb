require "googlecalendar/service_base"

module GoogleCalendar
  #
  # this class interacts with Google Calendar and uses AuthSub interface for authentication.
  #
  class ServiceAuthSub < ServiceBase

    def initialize(token)
      @auth = token
    end 

  private 
    def add_authorize_header(header)
      header["Authorization"] = "AuthSub token=#{@auth}"
    end
  end # ServiceAuthSub
end # GoogleCalendar
