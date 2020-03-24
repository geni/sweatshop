# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'sweatshop'
  s.version = "1.7.0"
  s.date = '2011-04-05'
  s.authors = ["Amos Elliston", "Mike Stangel", "Scott Steadman"]
  s.email = 'mike@geni.com'
  s.default_executable = 'sweatd'
  s.summary = 'A simple asynchronous worker queue build on top of rabbitmq/ampq'
  s.executables = ["sweatd"]
  s.homepage = 'http://github.com/geni/sweatshop'
  s.require_paths = ["lib"]
end
