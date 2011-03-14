require 'mongo'

module Animoto
  module Mongo
    module RetriableReplSetConnectionPatch

      def reconnect_sleep_time=(time)
        @reconnect_sleep_time = time
      end

      def reconnect_sleep_time
        @reconnect_sleep_time ||= 0.25
      end

      def reconnect_attempts=(num)
        @reconnect_attempts = num
      end

      def reconnect_attempts
        @reconnect_attempts ||= 120
      end

      def send_message(operation, message, log_message=nil)
        retries = 0
        begin
          add_message_headers(message, operation)
          packed_message = message.to_s
          socket = checkout_writer
          send_message_on_socket(packed_message, socket)
        rescue ::Mongo::ConnectionFailure => e
          retries += 1
          raise e if self.reconnect_attempts < retries
          puts "retrying send_message..."
          sleep(self.reconnect_sleep_time)
          retry
        ensure
          checkin_writer(socket)
        end
      end

      def send_message_with_safe_check(operation, message, db_name, log_message=nil, last_error_params=false)
        docs = num_received = cursor_id = ''
        add_message_headers(message, operation)

        last_error_message = BSON::ByteBuffer.new
        build_last_error_message(last_error_message, db_name, last_error_params)
        last_error_id = add_message_headers(last_error_message, ::Mongo::Constants::OP_QUERY)

        packed_message = message.append!(last_error_message).to_s
        retries = 0
        begin
          sock = checkout_writer
          @safe_mutexes[sock].synchronize do
            send_message_on_socket(packed_message, sock)
            docs, num_received, cursor_id = receive(sock, last_error_id)
          end
        rescue ::Mongo::ConnectionFailure => e
          retries += 1
          puts "Retry: #{retries}/#{self.reconnect_attempts}"
          raise e if self.reconnect_attempts < retries
          puts "retrying send_message with safe check..."
          sleep(self.reconnect_sleep_time)
          retry
        ensure
          checkin_writer(sock)
        end

        if num_received == 1 && (error = docs[0]['err'] || docs[0]['errmsg'])
          close if error == "not master"
          error = "wtimeout" if error == "timeout"
          raise ::Mongo::OperationFailure, docs[0]['code'].to_s + ': ' + error
        end

        docs[0]
      end

      def receive_message(operation, message, log_message=nil, socket=nil, command=false)
        request_id = add_message_headers(message, operation)
        packed_message = message.to_s
        retries = 0
        begin
          if socket
            sock = socket
            checkin = false
          else
            sock = (command ? checkout_writer : checkout_reader)
            checkin = true
          end

          result = ''
          @safe_mutexes[sock].synchronize do
            send_message_on_socket(packed_message, sock)
            result = receive(sock, request_id)
          end
        rescue ::Mongo::ConnectionFailure => e
          retries += 1
          raise e if self.reconnect_attempts < retries
          puts "retrying recieve message..."
          sleep(self.reconnect_sleep_time)
          retry
        ensure
          if checkin
            command ? checkin_writer(sock) : checkin_reader(sock)
          end
        end
        result
      end
    end

    class RetriableReplSetConnection < ::Mongo::ReplSetConnection
      include ::Animoto::Mongo::RetriableReplSetConnectionPatch
    end
  end
end

#Mongo::ReplSetConnection.send(:include, Animoto::Mongo::RetriableReplSetConnectionPatch)
