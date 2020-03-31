require_relative 'daemoned'

module Sweatshop
  class Sweatd
    include Daemoned
    queues     = []
    groups     = []
    rails_root = nil
    start_cmd  = "ruby #{__FILE__} start #{ARGV.reject{|a| a == 'start'}.join(' ')}"

    arg '--workers=Worker,Worker', 'Workers to service (Default is all)' do |value|
      queues = value.split(',')
    end

    arg '--groups=GROUP,GROUP', 'Groups of queues to service' do |value|
      groups = value.split(',').collect{|g| g.to_sym}
    end

    arg '--worker-file=WORKERFILE', 'Worker file to load'  do |value|
      require value
    end

    arg '--worker-dir=WORKERDIR', 'Directory containing workers'  do |value|
      Dir.glob(value + '*.rb').each{|worker| require worker}
    end

    arg '--rails=DIR', 'Pass in RAILS_ROOT to run this daemon in a rails environment' do |value|
      rails_root = value
    end

    sig(:term, :int) do
      puts "Shutting down sweatd..."
      Sweatshop.stop
    end

    sig(:hup) do
      puts "Received HUP"
      Sweatshop.stop do
        remove_pid!
        puts "Restarting sweatd with #{start_cmd}..."
        `#{start_cmd}`
      end
    end

    before do
      if rails_root
        puts "Loading Rails..."
        require rails_root + '/config/environment'
      end
      require_relative '../sweatshop'
    end

    daemonize(:kill_timeout => 20) do
      workers = []

      Sweatshop.daemonize

      if groups.any?
        workers += Sweatshop.workers_in_group(groups)
      end

      if queues.any?
        workers += queues.collect{|q| Object.module_eval(q)}
      end

      if workers.any?
        worker_str = workers.join(',')
        puts "Starting #{worker_str}..."
        $0 = "Sweatd: #{worker_str}"
        Sweatshop.workers = workers
      else
        puts "Starting all workers..."
        $0 = 'Sweatd: all'
      end

      Sweatshop.do_tasks
    end

  end
end
