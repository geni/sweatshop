require 'test_helper'
require 'securerandom'

class RabbitTest < TestHelper

  test 'initialize sets default tls false' do
    rabbit = MessageQueue::Rabbit.new

    assert_equal false, rabbit.opts[:tls]
  end

  test 'initialize preserves tls value when provided' do
    rabbit = MessageQueue::Rabbit.new(:tls => true)

    assert_equal true, rabbit.opts[:tls]
  end

  test 'delete removes an existing queue' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      rabbit.enqueue(queue, :value => 1)
      sleep 0.5
      assert_equal 1, rabbit.queue_size(queue)

      rabbit.delete(queue)
      assert_equal 0, rabbit.queue_size(queue)
    end
  end

  test 'queue_size reports the number of queued messages' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      rabbit.flush_all(queue)

      rabbit.enqueue(queue, :a => 1)
      rabbit.enqueue(queue, :b => 2)
      rabbit.enqueue(queue, :c => 3)
      sleep 0.5
      assert_equal 3, rabbit.queue_size(queue)

      rabbit.flush_all(queue)
    end
  end

  test 'enqueue stores and dequeue returns marshaled data' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      data = { :hello => 'world', :count => 2 }
      rabbit.flush_all(queue)

      rabbit.enqueue(queue, data)
      assert_equal data, rabbit.dequeue(queue)
      assert_nil rabbit.dequeue(queue)
    end
  end

  test 'dequeue with default ack removes message immediately' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      task = { :method => :work, :args => [1] }
      rabbit.flush_all(queue)
      rabbit.enqueue(queue, task)

      dequeued = rabbit.dequeue(queue)
      assert_equal task, dequeued
      assert_nil rabbit.dequeue(queue)
    end
  end

  test 'dequeue with ack false can be confirmed' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      task = { :method => :work, :args => ['x'] }
      rabbit.flush_all(queue)
      rabbit.enqueue(queue, task)

      assert_equal task, rabbit.dequeue(queue, false)
      rabbit.confirm(queue)
      assert_nil rabbit.dequeue(queue)
    end
  end

  test 'dequeue returns nil when task payload missing' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      rabbit.flush_all(queue)
      assert_nil rabbit.dequeue(queue)
    end
  end

  test 'confirm does not error when no delivery tag exists' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      rabbit.flush_all(queue)
      rabbit.confirm(queue)
      assert true
    end
  end

  test 'flush_all removes all queued messages' do
    with_rabbit do |rabbit|
      queue = unique_queue_name
      rabbit.enqueue(queue, :x => 1)
      rabbit.enqueue(queue, :y => 2)
      sleep 0.5
      assert_equal 2, rabbit.queue_size(queue)

      rabbit.flush_all(queue)
      assert_equal 0, rabbit.queue_size(queue)
    end
  end

  test 'reset clears connections and allows reconnect on next operation' do
    queue = unique_queue_name
    rabbit = MessageQueue::Rabbit.new(rabbit_options)
    rabbit.flush_all(queue)
    rabbit.enqueue(queue, :value => 1)

    rabbit.reset!

    assert_equal 1, rabbit.queue_size(queue)
    rabbit.flush_all(queue)
  ensure
    rabbit.reset! if rabbit
  end

private

  def rabbit_options
    {
      'host' => "#{ENV.fetch('RABBITMQ_HOST', 'localhost')}:#{ENV.fetch('RABBITMQ_PORT', '5672')}"
    }
  end

  def unique_queue_name
    "rabbit_test_#{name.gsub(/\W+/, '_')}_#{SecureRandom.hex(6)}"
  end

  def with_rabbit
    rabbit = MessageQueue::Rabbit.new(rabbit_options)
    yield rabbit
  ensure
    rabbit.reset! if rabbit
  end

end # class RabbitTest
