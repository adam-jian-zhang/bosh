require 'spec_helper'
require 'nats/nats_users_sync'
require 'rest-client'
require 'nats/bosh_config'

module Nats
  describe NatsUsersSync do
    subject { NatsUsersSync.new(stdout, nats_config_file_path, bosh_config) }
    let(:stdout) { StringIO.new }
    let(:nats_config_file_path) { Tempfile.new('nats_config.json').path }
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
      describe 'when there are deployments with running vms in Bosh' do
        before do
          stub_request(:get, url + '/deployments/deployment-1/vms')
            .with(basic_auth: [user, password])
            .to_return(status: 200, body: vms_json)
          stub_request(:get, url + '/deployments')
            .with(basic_auth: [user, password])
            .to_return(status: 200, body: deployments_json)
          subject.execute_nats_sync
        end

        it 'should write the right number of users to the NATs configuration file in the given path' do
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'].length).to eq(4)
        end

        it 'should write the right agent_ids to the NATs configuration file in the given path' do
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
          file = File.read(nats_config_file_path)
          data_hash = JSON.parse(file)
          expect(data_hash['authorization']['users'])
            .not_to include(include('user' => format(ldap_user_name_base, '9cb7120d-d817-40f5-9410-d2b6f01ba746.agent')))
          expect(data_hash['authorization']['users'])
            .not_to include(include('user' => format(ldap_user_name_base, '209b96c8-e482-43c7-9f3e-04de9f93c535.agent')))
        end
      end
    end
  end
end
