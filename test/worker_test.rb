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
