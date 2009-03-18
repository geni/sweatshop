# hack for functional tests
require File.dirname(__FILE__) + '/../../../memcache/lib/memcache_extended'
require File.dirname(__FILE__) + '/../../../memcache/lib/memcache_util'

class HelloWorker < SweatShop::Worker
  TEST_FILE = File.dirname(__FILE__) + '/test.txt' unless defined?(TEST_FILE)

  def hello(name)
    puts name
    "Hi, #{name}"
  end

  after_task do |task|
    File.open(TEST_FILE, 'w'){|f| f << task[:result]}
  end
end
