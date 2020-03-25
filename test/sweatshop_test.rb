require 'test_helper'

class SweatshopTest < TestHelper

  class GroupedWorker < Sweatshop::Worker
    queue_group :foo
  end

  test 'workers_in_group' do
    assert_equal [HelloWorker, SweatshopTest::GroupedWorker].sort_by(&:name), Sweatshop.workers_in_group(:all).sort_by(&:name)
    assert_equal [HelloWorker],   Sweatshop.workers_in_group(:default)
    assert_equal [SweatshopTest::GroupedWorker], Sweatshop.workers_in_group(:foo)
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
end
