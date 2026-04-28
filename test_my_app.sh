#!/bin/sh

bundle config --local clean true
bundle config --local path vendor/bundle
bundle config --local without vscode

rm -rf Gemfile.lock vendor/bundle coverage
bundle install

[[ " $* " =~ " --no-docker " ]] || bin/docker_start_rabbitmq.sh

bundle exec rake test
test_exit_code=$?

[[ " $* " =~ " --no-docker " ]] || bin/docker_stop_rabbitmq.sh

exit $test_exit_code
