module NATSSync
  class Runner
    include YamlHelper

    def initialize(config_file, stdout)
      config = load_yaml_file(config_file)
      director_config = config['director']
      @bosh_config = BoshConfig.new(director_config['api'], director_config['user'], director_config['password'])
      @poll_user_sync = config['intervals']['poll_user_sync']
      @nats_config_file_path = config['nats']['config_file_path']
      @nats_server_executable = config['nats']['nats_server_executable']
      # TODO: remove this and use a logger
      @stdout = stdout
    end

    def run
      @stdout.puts('Nats Sync starting...')
      EM.error_handler { |e| handle_em_error(e) }
      EM.run do
        setup_timers
      end
    end

    def stop
      EM.stop_event_loop
    end

    private

    def setup_timers
      EM.schedule do
        EM.add_periodic_timer(@poll_user_sync) { sync_nats_users }
      end
    end

    def sync_nats_users
      UsersSync.new(@stdout, @nats_config_file_path, @bosh_config, @nats_server_executable).execute_users_sync
    end

    def handle_em_error(err)
      @shutting_down = true
      log_exception(err, :fatal)
      stop
    end

    def log_exception(err, level = :error)
      level = :error unless level == :fatal
      @stdout.puts(level, err.to_s)
    end
  end
end
