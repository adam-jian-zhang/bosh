require 'rest-client'
require 'base64'

module Nats
  class NatsUsersSync
    def initialize(stdout, nats_config_file, bosh_config)
      @stdout = stdout
      @nats_config_file = nats_config_file
      @bosh_config = bosh_config
    end

    def execute_nats_sync
      @stdout.puts 'Executing NATS Synchronization'
      vms_uuids = query_all_running_vms
      # write_nats_config_file(vms_uuids)
      @stdout.puts 'Finishing NATS Synchronization'
      vms_uuids
    end

    private

    def call_bosh_api(endpoint)
      response = RestClient.get @bosh_config.url + endpoint, 'Authentication:' => encode_basic_authentication
      raise('Cannot access BOSH endpoint: ' + endpoint) unless response.code == 200

      response.body
    end

    def query_all_deployments
      deployments_json = JSON.parse(call_bosh_api('/deployments'))
      deployments_json.map { |deployment| deployment['name'] }
    end

    def get_vms_by_deployment(deployment)
      deployments = JSON.parse(call_bosh_api('/deployments/' + deployment + '/vms'))
      deployments.map { |deployment_obj| deployment_obj['agent_id'] }
    end

    def query_all_running_vms
      deployments = query_all_deployments
      vms_uuids = []
      deployments.each { |deployment| vms_uuids += get_vms_by_deployment(deployment) }
      vms_uuids
    end

    def encode_basic_authentication
      'Basic ' + Base64.encode64(@bosh_config.user + ':' + @bosh_config.password)
    end

    # def write_nats_config_file(vms_uuids)
    #
    # end
  end
end
