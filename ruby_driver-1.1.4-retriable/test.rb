#!/usr/bin/env ruby

$: << File.expand_path('../..', __FILE__)

require 'yaml'
require 'common/basic_test'
require 'common/robust_connection'

config_path = File.expand_path('../../db.config.yml', __FILE__)

#class Mongo::Connection
  #include ::Animoto::Mongo::Robustify
#end

module MongoTest
  class OneOneFourRetriable < Base

    def connect
      self.connection = ::Mongo::Connection.multi(repl_set_nodes)
    end

  end
end

test = MongoTest::OneOneFourRetriable.new
test.setup_connection(YAML.load_file(config_path))
test.start_test

