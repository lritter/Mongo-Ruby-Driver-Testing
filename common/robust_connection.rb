require 'mongo'

module Animoto
module Mongo

  module Robustify

    def self.included(klass)
      puts klass.name
      klass.const_set(:METHOD_TABLE, {})

      supress_retry do
        #klass.instance_methods(false)
        [:send_message, :send_message_with_safe_check, :receive_message].each do |method_name|
          retry_method(klass, method_name.to_sym)
        end
      end

      def klass.method_added(name)
        return if @_adding_method
        @_adding_method = true
        retry_method(self, name)
        @_adding_method = false
      end
    end

    def self.supress_retry
      old_val = Thread.current[:'supressing retry']
      Thread.current[:'supressing retry'] = true
      puts "supress was #{old_val} and now is #{Thread.current[:'supressing retry']}"
      yield
    ensure
      puts "supress is back to #{Thread.current[:'supressing retry']}"
      Thread.current[:'supressing retry'] = old_val
    end

    def self.ok_to_retry?
      !Thread.current[:'supressing retry']
    end

    def self.retry_method(klass, name)
      method_table = klass.const_get(:METHOD_TABLE)
      #return if method_table[name]
      method_table[name] = klass.instance_method(name)
      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}(*args, &block)
          my_id = self.object_id
          method_object = METHOD_TABLE[:'#{name}'].bind(self)
          result = nil
          if ::Animoto::Mongo::Robustify.ok_to_retry?
            rescue_connection_failure('#{name}') do
              puts "calling \#{self.class.name}##{name}/\#{my_id} within retry block"
              ::Animoto::Mongo::Robustify.supress_retry do
                result = method_object.call(*args, &block)
              end
            end
          else
            puts "calling \#{self.class.name}##{name}\#{my_id} without retry block"
            result = method_object.call(*args, &block)
          end
          result
        end
      RUBY

    end
    
    def rescue_connection_failure(message, max_retries=120, sleep_interval=0.25)
      retries = 0
      begin
        result = yield
        puts "Reconnected: #{Process.pid} #{Time.now}" if retries != 0
        result
      rescue ::Mongo::ConnectionFailure => ex
        retries += 1
        puts "Connection Failure: #{message} #{Process.pid}"#, *ex.backtrace
        #puts "#{ex.message}"
        raise ex if retries > max_retries
        sleep(sleep_interval)
        #::Animoto::Mongo::Robustify.supress_retry { connect }
        #reconnect
        puts "Retrying #{message}: #{Process.pid} #{Time.now}"
        retry
      rescue Exception => e
        puts "Exception with #{message} #{Process.pid}"
        puts e.message, *e.backtrace
        raise e
      end
    end


  end
  
  
end
end


