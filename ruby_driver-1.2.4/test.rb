#!/usr/bin/env ruby

$: << File.expand_path('../..', __FILE__)

require 'yaml'
require 'common/basic_test'
config_path = File.expand_path('../../db.config.yml', __FILE__)

class ReplSetConnectionTest < MongoTest::Base
  
  def connect(config)
    self.connection = Mongo::ReplSetConnection.new(*config['repl_set'])
  end

  def write_item(collection)
    rescue_connection_failure('write') do
      super
    end
  end

  def read_item(collection)
    rescue_connection_failure('read') do
      super
    end
  end
end

test = ReplSetConnectionTest.new
test.setup_connection(YAML.load_file(config_path))
test.start_test
