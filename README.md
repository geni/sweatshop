# Sweatshop

Sweatshop provides an api to background resource intensive tasks. Much of the api design was copied from Workling, with a few tweaks. Currently, it runs rabbitmq and kestrel, but it can support any number of queues.

## Testing

```sh
test_my_app.sh
```

## Installing

```sh
# Gemfile
gem 'sweatshop', :git => 'https://github.com/geni/sweatshop.git'
```

```yaml
# config/sweatshop.yml
development:
  default:
    queue: rabbit
    host: localhost:5672
  enable: true
test:
  default:
    queue: rabbit
    host: localhost:5672
  enable: true
production:
  default:
    queue: rabbit
    host: rabbit:5672
  enable: true
```

## Writing workers

Put `email_worker.rb` into app/workers and sublcass `Sweatshop::Worker`:

```ruby
class EmailWorker < Sweatshop::Worker
  def send_mail(to)
    user = User.find_by_id(to)
    Mailer.deliver_welcome(to)
  end
end
```

Then, anywhere in your app you can execute:

```ruby
EmailWorker.async_send_mail(1)
```

The `async` signifies that this task will be placed on a queue to be serviced by the EmailWorker possibly on another machine. You can also
call:

```ruby
EmailWorker.send_mail(1)
```

That will do the work immediately, without placing the task on the queue. You can also define a `queue_group` at the top of the file which will allow you to split workers out into logical groups. This is important if you have various machines serving different queues.

## Running the queue

Sweatshop has been tested with Rabbit and Kestrel, but it will also work with Starling. Please use the following resources to install the server:

[http://github.com/robey/kestrel/tree/master](Kestrel)

[http://github.com/ezmobius/nanite/tree/master](Rabbit)

config/sweatshop.yml specifies the machine address of the queue
(default localhost:5672). You can also specify the queue type with the
queue param.

## Rabbit cluster support

The following example configuration shows support for Rabbit clusters
within a queue group:

```yaml
# config/sweatshop.yaml
default:
  queue: rabbit
  cluster:
    - hostA:5672
    - hostB:5672
  user: 'guest'
  pass: 'guest'
  vhost: '/'
enable: true
```

Sweatshop will attempt to connect to each server listed under
"cluster" in order, until it either manages to establish a connection
or until it runs out of servers.

If you only have a single Rabbit server, you can omit the "cluster"
option and just add "host" and "port" (or host: localhost:5672) options, as shown below:

```yaml
# config/sweatshop.yaml
default:
  queue: rabbit
  host: localhost
  port: 5672
  user: 'guest'
  pass: 'guest'
  vhost: '/'
enable: true
```

## Running the workers

Assuming you ran `rake setup` in Rails, you can type:

```sh
bundle exec script/sweatshop
```

By default, the script will run all workers defined in the app/workers dir. Every task will be processed on each queue using a round-robin algorithm. You can also add the `-d` flag which will put the worker in daemon mode. The daemon also takes other params.  Add a `-h` for more details.

```sh
bundle exec script/sweatshop -d
bundle exec script/sweatshop -d stop
```

If you would like to run Sweatshop as a daemon on a linux machine, use the initd.sh script provided in the sweatshop/script dir.

## Requirements

- memcache (for kestrel)
- bunny gem (for rabbit)

## Ruby and Rails compatibility

Sweatshop is tested against Ruby 2.7.8 with Rails 2.3 and Ruby 3.4.1 with Rails 8.0, from a single
code path -- there are no version branches in the gem. A single RabbitMQ cluster can be shared by
producers and consumers running on either combination.

Rails is optional. When `Rails` is defined and `Rails.root` is set, sweatshop reads
`config/sweatshop.yml` for `Rails.env`; otherwise it falls back to the gem's own `config/defaults.yml`.
If the config file exists but has no section for the current environment, sweatshop logs that and
disables itself rather than raising.

### Upgrading: keyword arguments

Ruby 3 stopped converting a trailing Hash into keyword arguments. Sweatshop tags the arguments it
queues with `ruby2_keywords`, and the tag survives `Marshal`, so a worker method that takes keywords
receives keywords:

```ruby
class EmailWorker < Sweatshop::Worker
  def send_mail(to, cc: nil, bcc: nil)
    ...
  end
end

EmailWorker.async_send_mail(1, :cc => 2)   # cc: arrives as a keyword
```

A worker whose method takes a positional Hash is unaffected:

```ruby
class EmailWorker < Sweatshop::Worker
  def send_mail(to, options)
    ...
  end
end

EmailWorker.async_send_mail(1, :cc => 2)   # options arrives as {:cc => 2}
```

Messages enqueued by a release that predates this change carry no tag, so their trailing Hash
arrives positionally. Workers that take a positional Hash are fine; workers that take keywords are
not, and would fail on Ruby 3 with an `ArgumentError`. **Drain the queues before upgrading a worker
that takes keyword arguments.**

## License

Copyright (c) 2009 Amos Elliston, Geni.com; Published under The MIT License, see License
