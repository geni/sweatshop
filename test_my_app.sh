#!/bin/sh

unset RBENV_VERSION
export RBENV_ROOT=/opt/rbenv
export PATH=${RBENV_ROOT}/shims:${PATH}:${RBENV_ROOT}/bin

git gc

bundle config --local clean true
bundle config --local path vendor/bundle
bundle config --local without vscode

rm Gemfile.lock
bundle install

bin/docker_run_rabbitmq.sh

bundle exec rake test

