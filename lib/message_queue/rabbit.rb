require 'carrot'

module MessageQueue
  class Rabbit < Base

    def initialize(opts={})
      @opts = opts
    end

    def delete(queue)
      cluster_cmd(queue, :delete)
    end

    def queue_size(queue)
      cluster_cmd(queue, :message_count).max
    end

    def enqueue(queue, data)
      cluster_cmd(queue, :publish, Marshal.dump(data), :persistent => true, :only_first => true)
    end

    def dequeue(queue_name, ack=true)
      task = cluster_cmd(queue_name, :pop, :ack => ack, :in_reverse => true, :first_response => true)
      return unless task
      Marshal.load(task)
    end

    def confirm(queue)
      cluster_cmd(queue, :ack, :in_reverse => true, :first_response => true)
    end

    def flush_all(queue)
      cluster_cmd(queue, :purge)
    end

    # Issue geni/geni#2454
    def cluster_cmd(queue_name, command, *args)

      # remove our arguments so they don't get passed through to the client calls
      first_response  = false
      in_reverse      = false
      if args.last.is_a?(Hash)
        first_response = args.last.delete(:first_response)
        in_reverse     = args.last.delete(:in_reverse)
        only_first     = args.last.delete(:only_first)
      end
      args.pop if args.last.respond_to?(:empty?) && args.last.empty?

      return cmd(queue_name, command, *args) unless @opts['cluster']

      results         = [] unless first_response
      ordered_clients = in_reverse ? clients.reverse : clients

      ordered_clients.each do |client|
        begin
          result = client.queue(queue_name, :durable => true).send(command, *args)

          if only_first
            return result
          elsif first_response
            return result if result
          else
            results << result
          end
        rescue Carrot::AMQP::Server::ServerDown => e
          Sweatshop.log "Error #{e.message}. Trying next server..."
        end
      end

      return first_response ? nil : results
    end

    def cmd(queue, command, *args)
      retried = false
      begin
        client.queue(queue, :durable => true).send(command, *args)
      rescue Carrot::AMQP::Server::ServerDown => e
        if not retried
          Sweatshop.log "Error #{e.message}. Retrying..."
          @client = nil
          retried = true
          retry
        else
          raise e
        end
      end
    end

    def client
      return @client if @client

      if @opts['cluster']
        @client = clients.first

      else
        if @opts['host'] =~ /:/
          host, port = @opts['host'].split(':')
        else
          host = @opts['host']
          port = @opts['port']
        end
        @client = Carrot.new({:host => host, :port => port.to_i}.merge(@opts))
      end

      # check server connection
      @client.server

      return @client
    end

    # Issue geni/geni#2454
    def clients
      @clients ||= begin
        @opts['cluster'].map do |value|
          if value.is_a?(Array)
            server, opts = value
          else
            server, opts = value, @opts
          end

          begin
            host, port = server.split(':')
            client     = Carrot.new({:host => host, :port => port.to_i}.merge(opts))

            # check connection
            client.server

            client
          rescue Carrot::AMQP::Server::ServerDown => e
            Sweatshop.log "Error: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end.compact
      end
    end

    def client=(client)
      @client = client
    end

    def stop
      client.stop
    end

    # Issue geni/geni#2454
    def reset!
      if @clients
        @clients.each(&:stop)
        @clients = nil
      end

      if @client
        @client.stop
        @client  = nil
      end
    end
  end
end
