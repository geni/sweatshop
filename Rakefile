require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << ['lib', 'test']
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

task :default => :test

task :setup do
  require File.dirname(__FILE__) + '/install'
end
