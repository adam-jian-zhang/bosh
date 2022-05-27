module NATSSync
  class BoshConfig
    include Comparable
    attr_reader :url, :user, :password

    def initialize(url, user, password)
      @url = url
      @user = user
      @password = password
    end

    def <=>(other)
      (other.url <=> @url).abs + (other.user <=> @user).abs + (other.password <=> @password).abs
    end
  end
end
