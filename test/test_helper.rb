require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)

unless ENV['SKIP_COVERAGE']
  # This has to happen before other files are loaded
  require 'simplecov'
  SimpleCov.start do
    command_name 'Unit Tests'
    load_profile 'bundler_filter'
    load_profile 'test_frameworks'
  end
end

dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
require 'sweatshop'
require 'minitest/autorun'
require 'mocha/minitest'
require 'pp'

class TestHelper < Minitest::Test

  def self.test(name, &block)
    define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
  end

end # class TestHelper

class Object

  def tap_pp(*args)
    pp [*args, self]
    self
  end

end # class Object
