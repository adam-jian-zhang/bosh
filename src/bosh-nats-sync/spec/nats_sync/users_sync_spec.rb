require 'spec_helper'
require 'nats_sync/users_sync'
require 'rest-client'
require 'nats_sync/bosh_config'

module NATSSync
  describe UsersSync do
    subject { UsersSync.new(stdout, nats_config_file_path, bosh_config, nats_executable) }
    let(:stdout) { StringIO.new }
    let(:nats_config_file_path) { Tempfile.new('nats_config.json').path }
    let(:nats_executable) { '/var/vcap/packages/nats/bin/nats-server' }
    let(:bosh_config) { BoshConfig.new(url, user, password) }
    let(:url) { 'http://127.0.0.1:25555' }
    let(:user) { 'admin' }
    let(:password) { 'admin' }
    let(:ldap_user_name_base) { 'C=USA, O=Cloud Foundry, CN=%s.bosh-internal' }
    let(:deployments_json) do
      '[
  {
    "name": "deployment-1",
    "cloud_config": "none",
    "releases": [
      {
        "name": "cf",
        "version": "222"
      },
      {
        "name": "cf",
        "version": "223"
      }
    ],
    "stemcells": [
      {
        "name": "bosh-warden-boshlite-ubuntu-xenial-go_agent",
        "version": "621.74"
      },
      {
        "name": "bosh-warden-boshlite-ubuntu-xenial-go_agent",
        "version": "456.112"
      }
    ]
  }
]'
    end
    let(:vms_json) do
      '[
  {
    "agent_id":"fef068d8-bbdd-46ff-b4a5-bf0838f918d9",
    "cid":"e975f3e6-a979-40c3-723a-a30817944ae4",
    "job":"debug",
    "index":0,
    "id":"9cb7120d-d817-40f5-9410-d2b6f01ba746",
    "az":"z1",
    "ips":[],
    "vm_created_at":"2022-05-25T20:54:18Z",
    "active":false
  },
  {
    "agent_id":"c5e7c705-459e-41c0-b640-db32d8dc6e71",
    "cid":"e975f3e6-a979-40c3-723a-a30817944ae4",
    "job":"debug",
    "index":0,
    "id":"209b96c8-e482-43c7-9f3e-04de9f93c535",
    "az":"z1",
    "ips":[],
    "vm_created_at":"2022-05-25T20:54:18Z",
    "active":false
  }
]'
    end

    describe '#execute_nats_sync' do
      describe 'when there are no deployments with running vms in Bosh' do
        before do
          stub_request(:get, url + '/deployments')
            .with(basic_auth: [user, password])
            .to_return(status: 200, body: '[]')
        end
        it 'should write the basic bosh configuration ' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(ldap_user_name_base, 'default.director')))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(ldap_user_name_base, 'default.hm')))
          expect(data_hash['authorization']['users'].length).to eq(2)
        end
      end

      describe 'when there are deployments with running vms in Bosh' do
        before do
          stub_request(:get, url + '/deployments/deployment-1/vms')
            .with(basic_auth: [user, password])
            .to_return(status: 200, body: vms_json)
          stub_request(:get, url + '/deployments')
            .with(basic_auth: [user, password])
            .to_return(status: 200, body: deployments_json)
          allow(Kernel).to receive(:system).and_return(true)
        end

        it 'should write the right number of users to the NATs configuration file in the given path' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'].length).to eq(4)
        end

        it 'should write the right agent_ids to the NATs configuration file in the given path' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(ldap_user_name_base, 'default.director')))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(ldap_user_name_base, 'default.hm')))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(ldap_user_name_base, 'fef068d8-bbdd-46ff-b4a5-bf0838f918d9.agent')))
          expect(data_hash['authorization']['users'])
            .to include(include('user' => format(ldap_user_name_base, 'c5e7c705-459e-41c0-b640-db32d8dc6e71.agent')))
        end

        it 'should not write the wrong ids to the NATs configuration file in the given path' do
          subject.execute_users_sync
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .not_to include(include('user' => format(ldap_user_name_base, '9cb7120d-d817-40f5-9410-d2b6f01ba746.agent')))
          expect(data_hash['authorization']['users'])
            .not_to include(include('user' => format(ldap_user_name_base, '209b96c8-e482-43c7-9f3e-04de9f93c535.agent')))
        end

        it 'should restart the nats process' do
          expect(Kernel).to receive(:system).with("#{nats_executable} --signal reload")
          subject.execute_users_sync
        end

        describe 'when there is a previous configuration file with the same users' do
          before do
            write_config_file(%w[fef068d8-bbdd-46ff-b4a5-bf0838f918d9 c5e7c705-459e-41c0-b640-db32d8dc6e71])
          end

          it 'should not restart the NATs process' do
            expect(Kernel).not_to receive(:system)
            subject.execute_users_sync
          end
        end

        describe 'when there is a previous configuration file with different users' do
          before do
            write_config_file(%w[fef068d8-bbdd-46ff-b4a5-bf0838f918d9 209b96c8-e482-43c7-8f3e-04de9f93c535])
          end

          it 'should restart the NATs process' do
            expect(Kernel).to receive(:system).with("#{nats_executable} --signal reload")
            subject.execute_users_sync
          end
        end
      end

      def write_config_file(vms_uuids)
        File.open(nats_config_file_path, 'w') do |f|
          f.write(JSON.unparse(NatsAuthConfig.new(vms_uuids).create_config))
        end
      end
    end
  end
end
