module NATSSync
  class NatsAuthConfig
    def initialize(agent_ids)
      @agent_ids = agent_ids
      @config = { "authorization" =>
                    { "users" => [] } }
    end

    def director_user
      {
        "user" => "C=USA, O=Cloud Foundry, CN=default.director.bosh-internal",
        "permissions" => {
          "publish" => %w[ "agent.*","hm.director.alert" ],
          "subscribe" => ["director.>"]
        }
      }
    end

    def hm_user
      {
        "user" => "C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal",
        "permissions" => {
          "publish" => [],
          "subscribe" => %w[
            "hm.agent.heartbeat.*",
            "hm.agent.alert.*",
            "hm.agent.shutdown.*",
            "hm.director.alert"
          ]
        }
      }
    end

    def agent_user(agent_id)
      {
        "user" => "C=USA, O=Cloud Foundry, CN=#{agent_id}.agent.bosh-internal",
        "permissions" => {
          "publish" => [
            "hm.agent.heartbeat.#{agent_id}",
            "hm.agent.alert.#{agent_id}",
            "hm.agent.shutdown.#{agent_id}",
            "director.*.#{agent_id}.*",
          ]
        },
        "subscribe": ["agent.#{agent_id}"]
      }
    end

    def create_config
      @config["authorization"]["users"] << director_user
      @config["authorization"]["users"] << hm_user
      @agent_ids.each { |agent_id| @config["authorization"]["users"] << agent_user(agent_id) }

      return @config
    end
  end
end