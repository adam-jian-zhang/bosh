require File.expand_path('../../../spec_helper', __FILE__)

module Bosh::Director
  describe Jobs::VmState do
    before do
      @deployment = Models::Deployment.make
      @result_file = double('result_file')
      Config.stub(:result).and_return(@result_file)
      Config.stub(:dns_domain_name).and_return('microbosh')
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :vms }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      before { allow(AgentClient).to receive(:with_defaults).with('fake-agent-id', timeout: 5).and_return(agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      it 'parses agent info into vm_state' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => { 'name' => 'test_resource_pool' },
        )

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          status['ips'].should == ['1.1.1.1']
          status['dns'].should be_empty
          status['vm_cid'].should == 'fake-vm-cid'
          status['agent_id'].should == 'fake-agent-id'
          status['job_state'].should == 'running'
          status['resource_pool'].should == 'test_resource_pool'
          status['vitals'].should be_nil
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'parses agent info into vm_state with vitals' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => { 'name' => 'test_resource_pool' },
          'vitals' => {
            'load' => ['1', '5', '15'],
            'cpu' => { 'user' => 'u', 'sys' => 's', 'wait' => 'w' },
            'mem' => { 'percent' => 'p', 'kb' => 'k' },
            'swap' => { 'percent' => 'p', 'kb' => 'k' },
            'disk' => { 'system' => { 'percent' => 'p' }, 'ephemeral' => { 'percent' => 'p' } },
          },
        )

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          status['ips'].should == ['1.1.1.1']
          status['dns'].should be_empty
          status['vm_cid'].should == 'fake-vm-cid'
          status['agent_id'].should == 'fake-agent-id'
          status['job_state'].should == 'running'
          status['resource_pool'].should == 'test_resource_pool'
          status['vitals']['load'].should == ['1', '5', '15']
          status['vitals']['cpu'].should == { 'user' => 'u', 'sys' => 's', 'wait' => 'w' }
          status['vitals']['mem'].should == { 'percent' => 'p', 'kb' => 'k' }
          status['vitals']['swap'].should == { 'percent' => 'p', 'kb' => 'k' }
          status['vitals']['disk'].should == { 'system' => { 'percent' => 'p' }, 'ephemeral' => { 'percent' => 'p' } }
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should return DNS A records if they exist' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        domain = Models::Dns::Domain.make(name: 'microbosh', type: 'NATIVE')

        Models::Dns::Record.make(
          domain: domain,
          name: 'index.job.network.deployment.microbosh',
          type: 'A',
          content: '1.1.1.1',
          ttl: 14400,
        )

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'job_state' => 'running',
          'resource_pool' => { 'name' => 'test_resource_pool' },
        )

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          status['ips'].should == ['1.1.1.1']
          status['dns'].should == ['index.job.network.deployment.microbosh']
          status['vm_cid'].should == 'fake-vm-cid'
          status['agent_id'].should == 'fake-agent-id'
          status['job_state'].should == 'running'
          status['resource_pool'].should == 'test_resource_pool'
          status['vitals'].should be_nil
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should handle unresponsive agents' do
        Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        expect(agent).to receive(:get_state).with('full').and_raise(RpcTimeout)

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          status['vm_cid'].should == 'fake-vm-cid'
          status['agent_id'].should == 'fake-agent-id'
          status['job_state'].should == 'unresponsive agent'
          status['resurrection_paused'].should be_nil
        end

        job = Jobs::VmState.new(@deployment.id, 'full')
        job.perform
      end

      it 'should get the resurrection paused status' do
        vm = Models::Vm.make(deployment: @deployment, agent_id: 'fake-agent-id', cid: 'fake-vm-cid')

        Models::Instance.create(
          deployment: @deployment,
          job: 'dea',
          index: '0',
          state: 'started',
          resurrection_paused: true,
          vm: vm,
        )

        expect(agent).to receive(:get_state).with('full').and_return(
          'vm_cid' => 'fake-vm-cid',
          'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
          'agent_id' => 'fake-agent-id',
          'index' => 0,
          'job' => { 'name' => 'dea' },
          'job_state' => 'running',
          'resource_pool' => { 'name' => 'test_resource_pool' },
          'vitals' => {
            'load' => ['1', '5', '15'],
            'cpu' => { 'user' => 'u', 'sys' => 's', 'wait' => 'w' },
            'mem' => { 'percent' => 'p', 'kb' => 'k' },
            'swap' => { 'percent' => 'p', 'kb' => 'k' },
            'disk' => { 'system' => { 'percent' => 'p' }, 'ephemeral' => { 'percent' => 'p' } },
          },
        )

        job = Jobs::VmState.new(@deployment.id, 'full')

        expect(@result_file).to receive(:write) do |agent_status|
          status = JSON.parse(agent_status)
          expect(status['resurrection_paused']).to be(true)
        end

        job.perform
      end
    end

    describe '#process_vm' do
      before { allow(AgentClient).to receive(:with_defaults).with('fake-agent-id', timeout: 5).and_return(agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      context 'when job index returned as part of get_state agent response is an empty string' do
        let(:vm) { Models::Vm.make(agent_id: 'fake-agent-id', cid: 'fake-vm-cid', deployment: @deployment) }

        # This test only makes sense for Postgres DB because it used to raise following error:
        #   #<Sequel::DatabaseError: PG::Error: ERROR:  invalid input syntax for integer: ""
        #   LINE 1: ..._id" = 8) AND ("job" = 'fake job') AND ("index" = '')) LIMIT...
        it 'does not raise Sequel::DatabaseError' do
          expect(agent).to receive(:get_state).with('full').and_return(
            'vm_cid' => 'fake vm',
            'networks' => { 'test' => { 'ip' => '1.1.1.1' } },
            'agent_id' => 'fake-agent-id',
            'index' => '',
            'job' => { 'name' => 'fake job' },
          )

          job = Jobs::VmState.new(@deployment.id, 'full')

          expect { job.process_vm(vm) }.to_not raise_error
        end
      end
    end
  end
end
