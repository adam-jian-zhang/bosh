module Nats
  class BoshConfig
    attr_reader :url, :user, :password

    def initialize(url, user, password)
      @url = url
      @user = user
      @password = password
    end
  end
end
