require 'test_helper'

# Ruby 3 stopped converting a trailing Hash into keyword arguments.  These tests pin down that
# keywords still reach worker methods as keywords on both Ruby 2.7 and Ruby 3, including after a
# Marshal round trip through the queue, and that a genuinely positional Hash stays positional.
class KwargsTest < TestHelper

  # Stands in for MessageQueue::Rabbit so these tests need no server, while still exercising the
  # Marshal round trip that keyword arguments have to survive.
  class MarshalQueue < MessageQueue::Base
    def initialize
      @messages = {}
    end

    def enqueue(queue, data)
      messages(queue) << Marshal.dump(data)
    end

    def dequeue(queue, ack = true)
      payload = messages(queue).shift
      payload && Marshal.load(payload)
    end

    def queue_size(queue)
      messages(queue).size
    end

    def flush_all(queue)
      messages(queue).clear
    end

  private

    def messages(queue)
      @messages[queue] ||= []
    end
  end # class MarshalQueue

  class KwargsWorker < Sweatshop::Worker
    def greet(name, greeting: 'Hi', punct: '!')
      "#{greeting}, #{name}#{punct}"
    end

    def with_hash(name, opts)
      [name, opts]
    end

    def anything(*args, **opts)
      [args, opts]
    end
  end # class KwargsWorker

  # These tests drive the worker directly, so keep it out of the global registry -- other tests
  # assert on the exact contents of Sweatshop.registered_workers.
  Sweatshop.registered_workers.delete(KwargsWorker)

  def setup
    Sweatshop.logger       = :silent
    KwargsWorker.queue     = MarshalQueue.new
    Sweatshop.config['enable'] = true
  end

  def teardown
    KwargsWorker.queue = nil
    Sweatshop.reset!
  end

  test 'synchronous call through method_missing keeps keywords' do
    assert_equal 'Yo, Amos?', KwargsWorker.greet('Amos', :greeting => 'Yo', :punct => '?')
  end

  test 'inline async keeps keywords when sweatshop is disabled' do
    Sweatshop.config['enable'] = false

    assert_equal 'Yo, Amos!', KwargsWorker.async_greet('Amos', :greeting => 'Yo')
  end

  test 'keywords survive the queue round trip' do
    KwargsWorker.async_greet('Amos', :greeting => 'Yo', :punct => '?')

    task = KwargsWorker.dequeue
    KwargsWorker.do_task(task)

    assert_equal 'Yo, Amos?', task[:result]
  end

  test 'keywords and positional args survive together' do
    KwargsWorker.async_anything(1, 2, :three => 3)

    task = KwargsWorker.dequeue
    KwargsWorker.do_task(task)

    assert_equal [[1, 2], {:three => 3}], task[:result]
  end

  test 'a positional hash stays positional through the queue' do
    KwargsWorker.async_with_hash('Amos', :greeting => 'Yo')

    task = KwargsWorker.dequeue
    KwargsWorker.do_task(task)

    assert_equal ['Amos', {:greeting => 'Yo'}], task[:result]
  end

  test 'a positional hash stays positional on a synchronous call' do
    assert_equal ['Amos', {:greeting => 'Yo'}], KwargsWorker.with_hash('Amos', :greeting => 'Yo')
  end

  test 'do_task reports an unknown keyword through the exception handler' do
    exception = nil
    KwargsWorker.on_exception {|error| exception = error}

    KwargsWorker.async_greet('Amos', :nope => 1)
    KwargsWorker.do_task(KwargsWorker.dequeue)

    assert_equal ArgumentError, exception.class
    assert_match(/nope/, exception.message)
  ensure
    KwargsWorker.instance_variable_set(:@on_exception, nil)
  end

  # A task enqueued by a release that predates ruby2_keywords has no tag on its trailing Hash, so
  # it arrives as a positional Hash.  Workers that take a positional Hash are unaffected; workers
  # that take keywords are not -- see the upgrade note in the README.
  test 'a legacy payload still reaches a worker that takes a positional hash' do
    task = {:class => KwargsWorker.name, :method => 'with_hash', :args => ['Amos', {:greeting => 'Yo'}]}
    KwargsWorker.do_task(task)

    assert_equal ['Amos', {:greeting => 'Yo'}], task[:result]
  end

  test 'send_async still rejects the wrong number of positional args' do
    assert_raises(ArgumentError) do
      KwargsWorker.async_greet
    end
  end

end # class KwargsTest
