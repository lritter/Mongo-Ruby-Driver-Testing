require 'mongo'

module MongoTest
  class Base

    attr_accessor :connection
    attr_accessor :options
    attr_accessor :database

    Thread.abort_on_exception = false

    def setup_connection(config)
      puts "Mongo driver version: #{Mongo::VERSION}"
      puts "Setting up connection with: #{config.inspect}"
      connect(config)
      self.options = config['options'] || {}
      self.database = connection.db(options['database'] || 'test') 
    end

    def connect(config)
      self.connection = Mongo::ReplSetConnection.new(*config['repl_set'])
    end

    def rescue_connection_failure(message, max_retries=120)
      retries = 0
      begin
        result = yield
        puts "Reconnected: #{Process.pid} #{Time.now}" if retries != 0
        result
      rescue Mongo::ConnectionFailure => ex
        retries += 1
        puts "Connection Failure: #{message} #{Process.pid}"
        puts "#{ex.message}"
        raise ex if retries > max_retries
        sleep(0.5)
        puts "Retrying #{message}: #{Process.pid} #{Time.now}"
        retry
      rescue Exception => e
        puts "Exception with #{message} #{Process.pid}"
        puts e.message, *e.backtrace
        raise e
      end
    end

    def start_test
      if pid = fork
        write_test_data
        Process.wait(pid)
      else
        read_test_data
      end
    end

    def write_test_data
      mypid = Process.pid
      puts "Starting to write data: #{mypid} #{Time.now}"
      collection = database.collection('test')
      while(true)
        write_item(collection)
        sleep(0.25)
      end
    end

    def write_item(collection)
      #puts "writing: #{Process.pid} #{Time.now}"
      collection.insert({"at" => Time.now.to_i})
    end

    def read_test_data
      mypid = Process.pid
      puts "Starting to read data: #{mypid} #{Time.now}"
      collection = database.collection('test')
      while(true)
        read_item(collection)
        sleep(0.25)
      end
    end

    def read_item(collection)
      #puts "reading: #{Process.pid} #{Time.now}"
      collection.find_one({}, :sort => ['at', Mongo::DESCENDING])
    end

  end
end

