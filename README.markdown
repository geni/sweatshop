# Sweatshop

Sweatshop provides an api to background resource intensive tasks. Much of the api design was copied from Workling, with a few tweaks.
Currently, it runs rabbitmq and kestrel, but it can support any number of queues.

## RabbitMQ Development
  bundle install vendor/bundle
  # start RabbitMQ server
  # create a vhost named 'two'
  bundle exec rake test

## Installing

    gem install sweatshop
    freeze in your gems directory (add config.gem 'sweatshop' to your environment)
    cd vendor/gems/sweatshop
    rake setup

## Writing workers

Put `email_worker.rb` into app/workers and sublcass `Sweatshop::Worker`:

    class EmailWorker < Sweatshop::Worker
      def send_mail(to)
        user = User.find_by_id(to)
        Mailer.deliver_welcome(to)
      end
    end

Then, anywhere in your app you can execute:

    EmailWorker.async_send_mail(1)

The `async` signifies that this task will be placed on a queue to be serviced by the EmailWorker possibly on another machine. You can also
call:

    EmailWorker.send_mail(1)

That will do the work immediately, without placing the task on the queue. You can also define a `queue_group` at the top of the file
which will allow you to split workers out into logical groups. This is important if you have various machines serving different
queues.

## Running the queue

Sweatshop has been tested with Rabbit and Kestrel, but it will also work with Starling. Please use the following resources to install the server:

Kestrel:
http://github.com/robey/kestrel/tree/master

Rabbit:
http://github.com/ezmobius/nanite/tree/master

config/sweatshop.yml specifies the machine address of the queue
(default localhost:5672). You can also specify the queue type with the
queue param.

## Rabbit cluster support

The following example configuration shows support for Rabbit clusters
within a queue group:

        default:
          queue: rabbit
          cluster:
            - hostA:5672
            - hostB:5672
          user: 'guest'
          pass: 'guest'
          vhost: '/'
        enable: true

Sweatshop will attempt to connect to each server listed under
"cluster" in order, until it either manages to establish a connection
or until it runs out of servers.

If you only have a single Rabbit server, you can omit the "cluster"
option and just add "host" and "port" (or host: localhost:5672) options, as shown below:

       default:
         queue: rabbit
         host: localhost
         port: 5672
         user: 'guest'
         pass: 'guest'
         vhost: '/'
       enable: true


## Running the workers

Assuming you ran `rake setup` in Rails, you can type:

    script/sweatshop

By default, the script will run all workers defined in the app/workers dir. Every task will be processed on each queue using a round-robin algorithm. You can also add the `-d` flag which will put the worker in daemon mode. The daemon also takes other params.  Add a `-h` for more details.

    script/sweatshop -d
    script/sweatshop -d stop

If you would like to run Sweatshop as a daemon on a linux machine, use the initd.sh script provided in the sweatshop/script dir.

# REQUIREMENTS

    memcache (for kestrel)
    carrot (for rabbit)

# LICENSE

Copyright (c) 2009 Amos Elliston, Geni.com; Published under The MIT License, see License
