# This has to happen before other files are loaded
require 'simplecov'
SimpleCov.start do
  command_name 'Unit Tests'
  load_profile 'bundler_filter'
  load_profile 'test_frameworks'
end

dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
require 'sweatshop'
require 'minitest/autorun'
require 'pp'

class TestHelper < MiniTest::Test

  def self.test(name, &block)
    define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
  end

end
