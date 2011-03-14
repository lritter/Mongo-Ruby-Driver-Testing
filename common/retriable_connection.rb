require 'mongo'

module Animoto
module Mongo

  METHODS_TO_WRAP =  ::Mongo::Connection.allocate.methods - Object.methods
  
  class RetriableConnection < ::Mongo::Connection
    attr_accessor :max_retries
    attr_accessor :sleep_interval
    
    def initialize(host=nil, port=nil, options={})
      @max_retries = options.delete(:max_retries)
      @sleep_interval = options.delete(:sleep_interval)

      METHODS_TO_WRAP.each do |method_to_wrap|
        wrap_method_in_retry(method_to_wrap.to_sym)
      end
      super
    end
    
    def max_retries
      @max_retries || 5
    end
    
    def sleep_interval
      @sleep_interval || 1
    end
    
    private
    
    ##
    # Is execution currently in a retriable method?
    def currently_retrying?
      Thread.current[:mongo_connection_retrying]
    end
    
    ##
    # Set the value of the retrying flag.  Set to truthy to indicate that 
    # execution is currently in a retrying state
    def currently_retrying=(val)
      Thread.current[:mongo_connection_retrying] = val
    end
    
    def rescue_connection_failure(message)      
      self.currently_retrying = true
      success = false
      retries = 0
      return_val = nil
      while !success
        begin
          return_val = yield
          puts "Reconnected #{Process.pid} #{Time.now}" if retries != 0
          success = true
        rescue ::Mongo::ConnectionFailure => ex
          retries += 1
          raise ex if retries >= max_retries
          puts "Retrying #{message}: #{Process.pid} #{Time.now}"
          sleep(sleep_interval)
        end
      end
      return_val
    ensure
      self.currently_retrying = false
    end
    
    def wrap_method_in_retry(method_name)
      (class << self; self; end).class_eval do
        non_retry_method = "#{method_name}_without_retry"
        alias_method non_retry_method, method_name
        define_method method_name do |*args, &block|
          # If we're already retrying some other method, don't use the retrying 
          # version of the current method since we'll get an polynomial blowup
          # of retries.  Instead, call the non-retrying version since anything
          # that it throws should be caught by the calling retriable method.
          if self.send(:currently_retrying?)
            send(non_retry_method, *args, &block)
          else
            rescue_connection_failure(method_name.to_s) do
              send(non_retry_method, *args, &block)
              # lritter 2010-09-01 09:58:50: Use an aliased method instead of 
              # 'super' so that we can write tests around the non-wrapped method
              # being called X number of times.
              # super(*args, &block)
            end
          end
        end
      end
    end

    # Hack: The Mongo "add_message_headers" method mutilates it's inputs.
    # That makes it unsafe to retry. Here's a quick fix to prevent that.
    if ::Mongo::VERSION == "1.0.8"
      def add_message_headers_fix(operation, message)
        add_message_headers_buggy(operation, message.dup)
      end
      alias_method :add_message_headers_buggy, :add_message_headers
      alias_method :add_message_headers, :add_message_headers_fix
    else
      warn "retriable_connection: Check the need for :add_message_headers fix."
    end

  end
  
end
end

