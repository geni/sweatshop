require 'test_helper'
require 'hello_worker'

class WorkerTest < TestHelper

  def setup
    # use for low-level debugging
    # Carrot.logging = true
  end

  def teardown
    Sweatshop.flush_all_queues
    Sweatshop.reset!
    File.delete(HelloWorker::TEST_FILE) if File.exist?(HelloWorker::TEST_FILE)
  end

  test "daemonize" do
    enable_server do
      HelloWorker.async_hello('Amos')

      worker = File.expand_path(File.dirname(__FILE__) + '/hello_worker')
      sweatd = "#{File.dirname(__FILE__)}/../lib/sweatshop/sweatd.rb"

      system "ruby #{sweatd} --worker-file #{worker} start"
      system "ruby #{sweatd} stop"

      # help debug worker problem
      #system "cat sweatd.log"

      File.delete('sweatd.log') if File.exist?('sweatd.log')
      File.delete('sweatd.pid') if File.exist?('sweatd.pid')
      assert_equal 'Hi, Amos', File.read(HelloWorker::TEST_FILE)
    end
  end

  test "connect to fallback servers if the default one is down" do
    enable_server do
      Sweatshop.config['default']['cluster'] =
        [
         'localhost:5671', # invalid
         'localhost:5672'  # valid
        ]
      HelloWorker.async_hello('Amos')
      task = HelloWorker.dequeue

      assert_equal 'Amos', task[:args].first
    end
  end

  test "exception handler" do
    Sweatshop.logger = :silent
    exception = nil
    HelloWorker.on_exception do |e|
      exception = e
    end

    HelloWorker.do_task(nil)
    assert_equal NoMethodError, exception.class
  end

  # Issue geni/geni#2454
  test 'dequeue from rabbit cluster' do
    enable_server do
      Sweatshop.config['default']['cluster'] = {
        'localhost:5671' => {
          :port  => 5672, # have to change port here because hash keys must differ
          :vhost => '/',
        },
        'localhost:5672' => {
          :vhost => 'two',
        },
      }

      rabbit = Sweatshop.queue('default')
      queue = rabbit.clients.first.queue('HelloWorker', :durable => true)
      queue.publish(Marshal.dump(1), :persistent => true)
      queue.publish(Marshal.dump(2), :persistent => true)
      queue = rabbit.clients.last.queue('HelloWorker',  :durable => true)
      queue.publish(Marshal.dump(3), :persistent => true)
      queue.publish(Marshal.dump(4), :persistent => true)

      # localhost:5672/two should be drained before localhost:5672/
      assert_equal 3, HelloWorker.dequeue
      assert_equal 4, HelloWorker.dequeue
      assert_equal 1, HelloWorker.dequeue
      assert_equal 2, HelloWorker.dequeue
    end
  end

  # Issue geni/geni#2454
  test 'enqueue to rabbit cluster' do
    enable_server do
      Sweatshop.config['default']['cluster'] = {
        'localhost:5671' => {
          :port  => 5672, # have to change port here because hash keys must differ
          :vhost => '/',
        },
        'localhost:5672' => {
          :vhost => 'two',
        },
      }

      HelloWorker.async_hello('Scott')
      sleep 1

      rabbit = Sweatshop.queue('default')
      first = rabbit.clients.first.queue('HelloWorker', :durable => true)
      assert_equal 1, first.message_count, 'message should be queued in first server'
      last = rabbit.clients.last.queue('HelloWorker', :durable => true)
      assert_equal 0, last.message_count, 'message should not be queued in last server'
      assert_equal 1, HelloWorker.queue_size, 'message should be in queue'
    end
  end

  def enable_server
    Sweatshop.config['enable'] = true
    Sweatshop.logger = :silent
    begin
      yield
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
      fail "\n\n*** Functional test failed, is the rabbit server running on localhost? ***\n"
    end
  end
end
