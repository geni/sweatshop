require 'test_helper'
require 'sweatshop/daemoned'

# sweatd.rb daemonizes as a side effect of being loaded, so Daemoned is exercised through a bare
# host class instead.
class DaemonedTest < TestHelper

  def setup
    @original_program_name = $0
  end

  def teardown
    $0 = @original_program_name
  end

  # File.exists? was removed in Ruby 3.4, which took log_dir -- and so every sweatd start -- with
  # it.
  test 'log_dir finds an existing directory' do
    dir = daemon_class.send(:log_dir)

    refute_nil dir
    assert File.directory?(File.expand_path(dir)), "expected #{dir.inspect} to be a directory"
  end

  test 'log_file and pid_file land in the log dir' do
    daemon = daemon_class
    log_dir = File.expand_path(daemon.send(:log_dir))

    assert_equal log_dir, File.dirname(daemon.send(:log_file))
    assert_equal log_dir, File.dirname(daemon.send(:pid_file))
  end

private

  def daemon_class
    Class.new { include Daemoned }
  end

end # class DaemonedTest
