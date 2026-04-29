require 'test_helper'
require 'hello_worker'

class SweatshopTest < TestHelper

  class GroupedWorker < Sweatshop::Worker
    queue_group :foo
  end

  def teardown
    HelloWorker.instance_variable_set(:@before_task, nil)
    HelloWorker.instance_variable_set(:@after_task, nil)
    HelloWorker.instance_variable_set(:@on_exception, nil)
  end

  test 'workers_in_group' do
    assert_equal [HelloWorker, SweatshopTest::GroupedWorker].sort_by(&:name), Sweatshop.workers_in_group(:all).sort_by(&:name)
    assert_equal [HelloWorker],   Sweatshop.workers_in_group(:default)
    assert_equal [SweatshopTest::GroupedWorker], Sweatshop.workers_in_group(:foo)
    assert_equal [HelloWorker, SweatshopTest::GroupedWorker].sort_by(&:name), Sweatshop.workers_in_group([:default, :foo]).sort_by(&:name)
    assert_equal [HelloWorker, SweatshopTest::GroupedWorker].sort_by(&:name), Sweatshop.workers_in_group([:foo, :all]).sort_by(&:name)
    assert_equal [], Sweatshop.workers_in_group(:missing)
  end

  test "synch call" do
    worker = HelloWorker.new
    assert_equal "Hi, Amos", worker.hello('Amos')
  end

  test "have before task" do
    HelloWorker.before_task do
      "hello"
    end
    assert_equal "hello", HelloWorker.before_task.call
  end

  test "have after task" do
    HelloWorker.after_task do
      "goodbye"
    end
    assert_equal "goodbye", HelloWorker.after_task.call
  end

  test "chain before tasks" do
    MESSAGES = []
    class BaseWorker < Sweatshop::Worker
      before_task do |task|
        MESSAGES << 'base'
      end
    end
    class SubWorker < BaseWorker
      before_task do |task|
        MESSAGES << 'sub'
      end
    end
    SubWorker.call_before_task('foo')
    assert_equal ['base', 'sub'], MESSAGES
    Sweatshop.workers.delete(BaseWorker)
    Sweatshop.workers.delete(SubWorker)
  end

  test "run before and after callbacks during do_task" do
    callback_worker = Class.new(Sweatshop::Worker) do
      def perform(value)
        value * 2
      end
    end

    seen_before = nil
    seen_after = nil

    callback_worker.before_task do |task|
      seen_before = task.dup
    end
    callback_worker.after_task do |task|
      seen_after = task.dup
    end

    task = { :method => :perform, :args => [5] }
    callback_worker.do_task(task)

    assert_equal callback_worker, task[:worker_class]
    assert_equal 10, task[:result]
    assert_equal :perform, seen_before[:method]
    assert_equal [5], seen_before[:args]
    assert_equal 10, seen_after[:result]

    Sweatshop.workers.delete(callback_worker)
  end

  test "chain after tasks" do
    messages = []
    base_worker = Class.new(Sweatshop::Worker)
    sub_worker = Class.new(base_worker)

    base_worker.after_task do |_task|
      messages << 'base'
    end
    sub_worker.after_task do |_task|
      messages << 'sub'
    end

    sub_worker.call_after_task('foo')
    assert_equal ['base', 'sub'], messages

    Sweatshop.workers.delete(base_worker)
    Sweatshop.workers.delete(sub_worker)
  end

  test "chain exception handlers" do
    messages = []
    base_worker = Class.new(Sweatshop::Worker)
    sub_worker = Class.new(base_worker)

    base_worker.on_exception do |_exception|
      messages << 'base'
    end
    sub_worker.on_exception do |_exception|
      messages << 'sub'
    end

    sub_worker.call_exception_handler(StandardError.new('boom'))
    assert_equal ['base', 'sub'], messages

    Sweatshop.workers.delete(base_worker)
    Sweatshop.workers.delete(sub_worker)
  end
end
