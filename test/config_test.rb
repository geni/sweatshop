require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'pathname'

# Config loading has to behave the same under Rails 2.3 (Psych 3, Rails.root may be nil) and
# Rails 8 (Psych 4+, where YAML.load is safe by default and rejects aliases).
class ConfigTest < TestHelper

  ALIASED_YAML = <<-YML
shared: &shared
  queue: rabbit
  host: aliased-host:5672
test:
  default:
    <<: *shared
  enable: true
production:
  default:
    <<: *shared
  enable: false
  YML

  def setup
    @original_rails  = Object.const_defined?(:Rails) ? Object.const_get(:Rails) : nil
    Sweatshop.logger = :silent
    Sweatshop.reset!
  end

  def teardown
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, @original_rails) if @original_rails
    Sweatshop.reset!
  end

  test 'load_yaml resolves aliases' do
    with_yaml_file(ALIASED_YAML) do |file|
      loaded = Sweatshop.load_yaml(file)

      assert_equal 'aliased-host:5672', loaded['test']['default']['host']
    end
  end

  test 'load_yaml evaluates erb' do
    with_yaml_file("host: <%= 'erb-host' %>:5672\n") do |file|
      assert_equal 'erb-host:5672', Sweatshop.load_yaml(file)['host']
    end
  end

  test 'load_yaml restores symbols' do
    with_yaml_file("key: :a_symbol\n") do |file|
      assert_equal :a_symbol, Sweatshop.load_yaml(file)['key']
    end
  end

  test 'config loads the app config for the current rails env' do
    with_rails_app(ALIASED_YAML, 'test') do
      assert_equal 'aliased-host:5672', Sweatshop.config['default']['host']
      assert_equal true, Sweatshop.enabled?
    end
  end

  test 'config honours a different rails env' do
    with_rails_app(ALIASED_YAML, 'production') do
      assert_equal false, Sweatshop.enabled?
    end
  end

  test 'config falls back to disabled defaults when the env is missing' do
    with_rails_app(ALIASED_YAML, 'staging') do
      assert_equal false, Sweatshop.enabled?
      assert_equal 'rabbit', Sweatshop.config['default']['queue']
    end
  end

  test 'config falls back to disabled defaults when the app has no config file' do
    Dir.mktmpdir do |dir|
      stub_rails(Pathname.new(dir), 'test')

      assert_equal false, Sweatshop.enabled?
      assert_equal 'rabbit', Sweatshop.config['default']['queue']
    end
  end

  # Rails 2.3 defines Rails.root as nil until RAILS_ROOT is set, so Rails can be loaded without
  # an application.  That has to read as "not under Rails" rather than blow up on nil.join.
  test 'config uses the gem defaults when rails is loaded without a root' do
    stub_rails(nil, 'test')

    assert_equal true, Sweatshop.enabled?
    assert_equal 'rabbit', Sweatshop.config['default']['queue']
  end

  # Rails 2.3 hands back an ActiveSupport::StringInquirer and Rails 8 an EnvironmentInquirer,
  # neither of which is a plain String.
  test 'config indexes the file with a non-string rails env' do
    with_rails_app(ALIASED_YAML, Class.new(String).new('test')) do
      assert_equal 'aliased-host:5672', Sweatshop.config['default']['host']
    end
  end

private

  def with_yaml_file(yaml)
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'config.yml')
      File.open(file, 'w') {|handle| handle << yaml}
      yield file
    end
  end

  def stub_rails(root, env)
    rails = Module.new
    rails.define_singleton_method(:root) { root }
    rails.define_singleton_method(:env)  { env }
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
    Object.const_set(:Rails, rails)
    Sweatshop.reset!
  end

  def with_rails_app(yaml, env)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'config'))
      File.open(File.join(dir, 'config', 'sweatshop.yml'), 'w') {|handle| handle << yaml}
      stub_rails(Pathname.new(dir), env)
      yield dir
    end
  end

end # class ConfigTest
