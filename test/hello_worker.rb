require_relative '../lib/sweatshop'

# Use for low-level debugging
# Carrot.logging = true

class HelloWorker < Sweatshop::Worker
  TEST_FILE = File.dirname(__FILE__) + '/test.txt' unless defined?(TEST_FILE)

  def hello(name)
    puts name
    "Hi, #{name}"
  end

  after_task do |task|
    File.open(TEST_FILE, 'w'){|f| f << task[:result]}
  end
end
