require 'rest-client'
require 'base64'
require 'nats_sync/nats_auth_config'

module NATSSync
  class UsersSync
    def initialize(stdout, nats_config_file_path, bosh_config, nats_executable)
      @stdout = stdout
      @nats_config_file_path = nats_config_file_path
      @bosh_config = bosh_config
      @nats_executable = nats_executable
    end

    def execute_users_sync
      @stdout.puts 'Executing NATS Users Synchronization'
      vms_uuids = query_all_running_vms
      current_file_hash = nats_file_hash
      write_nats_config_file(vms_uuids)
      new_file_hash = nats_file_hash
      Kernel.system("#{@nats_executable} --signal reload") unless current_file_hash == new_file_hash
      @stdout.puts 'Finishing NATS Users Synchronization'
      vms_uuids
    end

    private

    def nats_file_hash
      Digest::MD5.file(@nats_config_file_path).hexdigest
    end

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
