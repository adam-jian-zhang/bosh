require 'spec_helper'

describe NATSSync::Runner do
  subject { NATSSync::Runner.new(sample_config, stdout) }
  let(:stdout) { StringIO.new }
  let(:user_sync_class) { class_double('NATSSync::UsersSync').as_stubbed_const }
  let(:user_sync_instance) { instance_double(NATSSync::UsersSync) }

  describe 'when the runner is created with the sample config file' do
    let(:bosh_config) { NATSSync::BoshConfig.new('http://127.0.0.1:25555', 'admin', 'admin') }
    let(:file_path) { '/tmp/example_file.yml' }
    before do
      allow(user_sync_instance).to receive(:execute_users_sync)
      allow(user_sync_class).to receive(:new).and_return(user_sync_instance)
      Thread.new do
        subject.run
      end
      sleep(2)
    end

    it 'should start UsersSync.execute_nats_sync function with the same parameters defined in the file' do
      expect(user_sync_class).to have_received(:new).with(stdout, file_path, bosh_config)
      expect(user_sync_instance).to have_received(:execute_users_sync)
    end

    after do
      subject.stop
    end
  end
end
