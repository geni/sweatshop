# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'sweatshop'
  s.version = "2.0.0"
  s.date = '2026-04-28'
  s.authors = ["Amos Elliston", "Mike Stangel", "Scott Steadman"]
  s.email = ['mike@geni.com', 'scott.steadman@geni.com']
  s.summary = 'A simple asynchronous worker queue built on top of RabbitMQ/AMQP'

  s.add_dependency 'bunny', '~>3.0'
  s.add_dependency 'erb'

  if ::RUBY_VERSION < '2.7'
    s.executables = ["sweatd"]
  end
  s.homepage = 'http://github.com/geni/sweatshop'
  s.require_paths = ["lib"]
end
