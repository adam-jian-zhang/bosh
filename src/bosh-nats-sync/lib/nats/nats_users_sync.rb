require 'rest-client'
require 'base64'
require 'nats/nats_auth_config'

module Nats
  class NatsUsersSync
    def initialize(stdout, nats_config_file_path, bosh_config)
      @stdout = stdout
      @nats_config_file_path = nats_config_file_path
      @bosh_config = bosh_config
    end

    def execute_nats_sync
      @stdout.puts 'Executing NATS Synchronization'
      vms_uuids = query_all_running_vms
      write_nats_config_file(vms_uuids)
      @stdout.puts 'Finishing NATS Synchronization'
      vms_uuids
    end

    private

    def call_bosh_api(endpoint)
      response = RestClient.get @bosh_config.url + endpoint, 'Authorization' => encode_basic_authentication
      raise("Cannot access: #{endpoint}, Status Code: #{response.code}, #{response.body}") unless response.code == 200

      response.body
    end

    def query_all_deployments
      deployments_json = JSON.parse(call_bosh_api('/deployments'))
      deployments_json.map { |deployment| deployment['name'] }
    end

    def get_vms_by_deployment(deployment)
      virtual_machines = JSON.parse(call_bosh_api("/deployments/#{deployment}/vms"))
      virtual_machines.map { |virtual_machine| virtual_machine['agent_id'] }
    end

    def query_all_running_vms
      deployments = query_all_deployments
      vms_uuids = []
      deployments.each { |deployment| vms_uuids += get_vms_by_deployment(deployment) }
      vms_uuids
    end

    def encode_basic_authentication
      "Basic #{Base64.encode64("#{@bosh_config.user}:#{@bosh_config.password}")}"
    end

    def write_nats_config_file(vms_uuids)
      File.open(@nats_config_file_path, 'w') do |f|
        f.write(JSON.unparse(NatsAuthConfig.new(vms_uuids).create_config))
      end
    end
  end
end
