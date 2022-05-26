require 'spec_helper'
require 'nats/nats_users_sync'
require 'rest-client'
require 'nats/bosh_config'

module Nats
  describe NatsUsersSync do
    subject { NatsUsersSync.new(stdout, nats_config_file, bosh_config) }
    let(:stdout) { StringIO.new }
    let(:nats_config_file) { '/file1.json' }
    let(:bosh_config) { BoshConfig.new(url, user, password) }
    let(:url) { 'http://127.0.0.1:25555' }
    let(:user) { 'admin' }
    let(:password) { 'admin' }
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
    let(:instances_json) do
      '[
  {
    "agent_id": "c5e7c705-459e-41c0-b640-db32d8dc6e71",
    "cid": "ec974048-3352-4ba4-669d-beab87b16bcb",
    "job": "example_service",
    "index": 0,
    "id": "209b96c8-e482-43c7-9f3e-04de9f93c535",
    "expects_vm": true
  },
  {
    "agent_id": null,
    "cid": null,
    "job": "example_errand",
    "index": 0,
    "id": "548d6aa0-eb8f-4890-bd3a-e6b526f3aeea",
    "expects_vm": false
  }
]'
    end

    describe '#execute_nats_sync' do
      describe 'when there are deployments with running vms in Bosh' do
        before do
          stub_request(:get, url + '/deployments/deployment-1/instances')
            .to_return(status: 200, body: instances_json)
          stub_request(:get, url + '/deployments')
            .to_return(status: 200, body: deployments_json)
        end

        it 'returns the vms belonging to the deployments' do
          expect(subject.execute_nats_sync).to eq(%w[209b96c8-e482-43c7-9f3e-04de9f93c535 548d6aa0-eb8f-4890-bd3a-e6b526f3aeea])
        end
      end
    end
  end
end
