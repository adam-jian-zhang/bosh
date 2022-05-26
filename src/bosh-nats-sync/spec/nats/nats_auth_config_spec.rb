require 'spec_helper'
require 'nats/nats_auth_config'

module Nats
  describe NatsAuthConfig do
    subject { NatsAuthConfig.new(agent_ids) }
    let(:agent_ids) { %w[fef068d8-bbdd-46ff-b4a5-bf0838f918d9 c5e7c705-459e-41c0-b640-db32d8dc6e71] }

    describe '#execute_nats_auth_config' do
      describe 'read config' do

        it 'returns the vms belonging to the deployments' do
          created_config = subject.create_config
          expect(created_config["authorization"]["users"].length).to eq(4)
        end
      end
    end
  end
end
