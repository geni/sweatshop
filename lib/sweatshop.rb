require 'rubygems'
require 'digest'
require 'erb'
require 'yaml'

$:.unshift(File.dirname(__FILE__))
require 'message_queue/base'
require 'message_queue/rabbit'
require 'message_queue/kestrel'

module Sweatshop
  extend self

  # Code reloading (Zeitwerk on Rails 8, Dependencies on Rails 2.3) hands us a brand new Class
  # object for the same worker on every reload, so registering by object identity alone would
  # leave the stale classes behind and double-count every queue.  Named workers replace any
  # earlier class of the same name; anonymous ones can only be deduped by identity.
  def register_worker(klass)
    if klass.name
      registered_workers.reject! {|worker| worker.name == klass.name}
    elsif registered_workers.include?(klass)
      return
    end

    registered_workers << klass
  end

  def registered_workers
    @registered_workers ||= []
  end

  def workers
    @workers ||= registered_workers
  end

  def workers=(workers)
    @workers = workers
  end

  def workers_in_group(groups)
    groups = [groups] unless groups.is_a?(Array)
    if groups.include?(:all)
      registered_workers
    else
      registered_workers.select do |worker|
        groups.include?(worker.queue_group)
      end
    end
  end

  def do_tasks
    loop do
      wait = true
      workers.each do |worker|
        if task = worker.dequeue
          worker.do_task(task)
          wait = false
        end
      end
      if stop?
        workers.each do |worker|
          worker.stop
        end
        queue.stop
        @stop.call if @stop.kind_of?(Proc)
        exit
      end
      sleep 1 if wait
    end
  end

  def do_all_tasks
    Sweatshop.workers = registered_workers
    do_tasks
  end

  def do_default_tasks
    Sweatshop.workers = workers_in_group(:default)
    do_tasks
  end

  def config
    @config ||= begin
      defaults = load_yaml(File.dirname(__FILE__) + '/../config/defaults.yml')

      if rails_root
        file = File.join(rails_root.to_s, 'config', 'sweatshop.yml')
        if File.exist?(file)
          env = rails_env
          load_yaml(file)[env] || begin
            log("No sweatshop configuration for #{env} in #{file}, disabling sweatshop")
            defaults['enable'] = false
            defaults
          end
        else
          defaults['enable'] = false
          defaults
        end
      else
        defaults
      end
    end
  end

  # Psych 4 (Ruby 3.1+) made YAML.load safe by default, which rejects the aliases and symbols
  # that sweatshop.yml files are allowed to use.  YAML.unsafe_load keeps Psych 3's behaviour but
  # does not exist on the Psych that ships with Ruby 2.7, hence the respond_to? rather than a
  # version check.
  def load_yaml(file)
    yaml = ERB.new(File.read(file)).result
    YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(yaml) : YAML.load(yaml)
  end

  # Rails 2.3 defines Rails.root as nil unless RAILS_ROOT is set, and Rails may be loaded
  # without an application at all (rake tasks, gems that reference the constant).  Anything
  # without a root is treated as "not running under Rails".
  def rails_root
    return nil unless defined?(Rails) && Rails.respond_to?(:root)
    Rails.root
  end

  # Rails 2.3 returns an ActiveSupport::StringInquirer here, Rails 8 an EnvironmentInquirer;
  # to_s gives us a plain String to index the config hash with either way.
  def rails_env
    Rails.env.to_s
  end

  def daemon?
    @daemon
  end

  def daemonize
    @daemon = true
  end

  def stop(&block)
    if block_given?
      @stop = block
    else
      @stop = true
    end
  end

  # Issue geni/geni#2454
  def reset!
    @config = nil

    if @queues
      @queues.values.each(&:reset!)
      @queues = nil
    end
  end

  def stop?
    @stop
  end

  def queue_sizes
    registered_workers.inject([]) do |all, worker|
      all << [worker, worker.queue_size]
      all
    end
  end

  def queue(type = 'default')
    type = config[type] ? type : 'default'
    return queues[type] if queues[type]

    qconfig = config[type]
    qtype   = qconfig['queue'] || 'rabbit'
    queue   = constantize("MessageQueue::#{qtype.capitalize}")

    queues[type] = queue.new(qconfig)
  end

  def queue=(queue, type = 'default')
    queues[type] = queue
  end

  def queues
    @queues ||= {}
  end

  def queue_groups
    @queue_groups ||= (workers.collect{|w| w.queue_group.to_s} << 'default').uniq
  end

  def flush_all_queues
    workers.each do |worker|
      worker.flush_queue
    end
  end

  def pp_sizes
    max_width = workers.collect{|w| w.to_s.size}.max
    puts '-' * (max_width + 10)
    puts queue_sizes.collect{ |p| sprintf("%-#{max_width}s %2s", p.first, p.last) }.join("\n")
    puts '-' * (max_width + 10)
  end

  def cluster_info
    servers = []
    queue_groups.each do |group|
      qconfig = config[group]
      next unless qconfig
      next unless qconfig['cluster']
      servers << qconfig['cluster']
    end
    servers = servers.flatten.uniq

    servers.each do |server|
      puts "\nQueue sizes on #{server}"
      queue = MessageQueue::Rabbit.new('host' => server)
      workers.each do |worker|
        worker.queue = queue
      end
      pp_sizes
      puts
    end
    workers.each{|w| w.queue = nil}
    nil
  end

  def enabled?
    !!config['enable']
  end

  def log(msg)
    return if logger == :silent
    logger ? logger.debug(msg) : puts(msg)
  end

  def logger
    defined?(@logger) && @logger
  end

  def logger=(logger)
    @logger = logger
  end

  def constantize(str)
    Object.module_eval("#{str}", __FILE__, __LINE__)
  end

end # module Sweatshop

require 'sweatshop/worker'
