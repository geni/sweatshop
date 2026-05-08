require_relative 'metaid'

module Sweatshop
  class Worker

    def self.inherited(subclass)
      Sweatshop.register_worker(subclass)
    end

    def self.method_missing(method, *args, &block)
      if method.to_s =~ /^async_(.*)/
        send_async($1, *args)
      elsif instance.respond_to?(method)
        instance.send(method, *args)
      else
        super
      end
    end

    def self.send_async(method, *args)
      check_arity!(instance.method(method), args)

      return instance.send(method, *args) unless async?

      uid  = ::Digest::MD5.hexdigest("#{name}:#{method}:#{args}:#{Time.now.to_f}")
      task = {:class => name, :method => method, :args => args, :uid => uid, :queued_at => Time.now.to_i}

      log("Putting #{name}.#{method} on #{queue_name} (uid #{uid})")
      enqueue(task)

      uid
    end

    def self.async?
      Sweatshop.enabled?
    end

    def self.instance
      new
    end

    def self.config
      Sweatshop.config
    end

    def self.queue_name
      to_s
    end

    def self.flush_queue
      queue.flush_all(queue_name)
    end

    def self.delete_queue
      queue.delete(queue_name)
    end

    def self.queue_size
      queue.queue_size(queue_name)
    end

    def self.enqueue(task)
      queue.enqueue(queue_name, task)
    end

    def self.dequeue(ack: true)
      queue.dequeue(queue_name, ack)
    end

    def self.confirm
      queue.confirm(queue_name)
    end

    def self.do_tasks
      while task = dequeue(ack: false)
        do_task(task)
      end
    ensure
      confirm
    end

    def self.do_task(task)
      worker_class =  if task.key?(:class)
                        if task[:class].respond_to?(:constantize)
                          task[:class].constantize
                        else
                          Object.const_get(task[:class])
                        end
                      end
      worker_class ||= self

      task[:worker_class] = worker_class
      call_before_task(task)

      queued_at = task[:queued_at] ? "(queued #{Time.at(task[:queued_at]).strftime('%Y/%m/%d %H:%M:%S')})" : ''
      uid       = task[:uid]       ? "(uid #{task[:uid]})" : ''
      log("Dequeuing #{task[:class]}::#{task[:method]} from #{queue_name} #{queued_at} #{uid}")

      instance = worker_class.respond_to?(:instance) ? worker_class.instance : worker_class.new
      task[:result] = instance.send(task[:method], *task[:args])

      call_after_task(task)
    rescue SystemExit
      exit
    rescue Exception => e
      log("Task: #{task.inspect}\nCaught Exception: #{e.message}, \n#{e.backtrace.join("\n")}")
      call_exception_handler(e)
    end

    def self.queue=(queue)
      @queue = queue
    end

    def self.queue
      # don't need to cache this
      # because it's already cached in Sweatshop
      return @queue if defined?(@queue)
      Sweatshop.queue(queue_group.to_s)
    end

    def self.workers
      Sweatshop.workers
    end

    def self.log(msg)
      Sweatshop.log(msg)
    end

    def self.call_before_task(task)
      superclass.call_before_task(task) if superclass.respond_to?(:call_before_task)
      before_task.call(task) if before_task
    end

    def self.call_after_task(task)
      superclass.call_after_task(task) if superclass.respond_to?(:call_after_task)
      after_task.call(task) if after_task
    end

    def self.call_exception_handler(exception)
      superclass.call_exception_handler(exception) if superclass.respond_to?(:call_exception_handler)
      on_exception.call(exception) if on_exception
    end

    def self.before_task(&block)
      if block
        @before_task = block
      elsif defined?(@before_task)
        @before_task
      end
    end

    def self.after_task(&block)
      if block
        @after_task = block
      elsif defined?(@after_task)
        @after_task
      end
    end

    def self.on_exception(&block)
      if block
        @on_exception = block
      elsif defined?(@on_exception)
        @on_exception
      end
    end

    def self.stop
      instance.stop
    end

    # called before we exit -- subclass can implement this method
    def stop; end;


    def self.queue_group(group=nil)
      group ? meta_def(:_queue_group){ group } : _queue_group
    end
    queue_group :default

  end # class Worker
end # module Sweatshop
