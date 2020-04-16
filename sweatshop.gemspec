# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'sweatshop'
  s.version = "1.7.1"
  s.date = '2011-04-05'
  s.authors = ["Amos Elliston", "Mike Stangel", "Scott Steadman"]
  s.email = 'mike@geni.com'
  s.summary = 'A simple asynchronous worker queue build on top of rabbitmq/ampq'
  if ::RUBY_VERSION < '2.7'
    s.executables = ["sweatd"]
  end
  s.homepage = 'http://github.com/geni/sweatshop'
  s.require_paths = ["lib"]
end
