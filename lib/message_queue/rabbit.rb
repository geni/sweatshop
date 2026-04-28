require 'bunny'

module MessageQueue
  class Rabbit < Base

    # A list of commands that must be executed on the client, not the queue
    CLIENT_COMMANDS = [:basic_ack]

    def initialize(opts={})
      @opts = opts.merge(:tls => false)
    end

    def delete(queue)
      cluster_cmd(queue, :delete)
    end

    def queue_size(queue)
      [cluster_cmd(queue, :message_count)].flatten.reduce(0) {|sum, count| sum + count.to_i}
    end

    def enqueue(queue, data)
      cluster_cmd(queue, :publish, Marshal.dump(data), :persistent => true, :only_first => true)
    end

    def dequeue(queue_name, ack=true)
      @delivery_info, properties, task = cluster_cmd(queue_name, :pop, :manual_ack => !ack, :in_reverse => true, :first_response => true)
      return unless task
      Marshal.load(task)
    end

    def confirm(queue)
      cluster_cmd(queue, :basic_ack, @delivery_info&.delivery_tag&.to_i)
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
          result = if CLIENT_COMMANDS.include?(command)
                     client.send(command, *args)
                   else
                     client.queue(queue_name, :durable => true).send(command, *args)
                   end

          if only_first
            return result
          elsif first_response
            if result.is_a?(Array) && result.compact.any?
              return result
            else
              next
            end
            return result if result
          else
            results << result
          end
        rescue Bunny::Exception => e
          Sweatshop.log "Error #{e.message}. Trying next server..."
        end
      end

      return first_response ? nil : results
    end

    def cmd(queue, command, *args)
      retried = false
      begin
        if CLIENT_COMMANDS.include?(command)
          client.send(command, *args)
        else
          client.queue(queue, :durable => true).send(command, *args)
        end
      rescue Bunny::Exception => e
        if not retried
          Sweatshop.log "Error #{e.message}. Retrying..."
          @client  = nil
          retried  = true
          retry
        else
          raise e
        end
      end
    end

    def client
      return @client if defined?(@client) && @client

      if @opts['cluster']
        @client = clients.first

      else
        if @opts['host'] =~ /:/
          host, port = @opts['host'].split(':')
        else
          host = @opts['host']
          port = @opts['port']
        end
        @opts[:logger] ||= Sweatshop.logger if Sweatshop.logger.is_a?(Logger)
        conn             = Bunny.new({:host => host, :port => port.to_i}.merge(opts))
      end

      # check server connection
      conn.start
      @client = conn.create_channel

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
            host, port       = server.split(':')
            @opts[:logger] ||= Sweatshop.logger if Sweatshop.logger.is_a?(Logger)
            conn             = Bunny.new({:host => host, :port => port.to_i}.merge(opts))

            # check connection
            conn.start
            conn.create_channel

          rescue Bunny::Exception => e
            Sweatshop.log "Error: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end.compact
      end
    end

    def client=(client)
      @client = client
    end

    def stop
      client&.close
    end

    # Issue geni/geni#2454
    def reset!
      if @clients
        @clients.each(&:close)
        @clients = nil
      end

      if @client
        @client.close
        @client  = nil
      end
    end
  end
end
