#!/usr/bin/env ruby

$: << File.expand_path('../..', __FILE__)

require 'yaml'
require 'common/basic_test'
require 'common/retriable_repl_set_connection'

config_path = File.expand_path('../../db.config.yml', __FILE__)

class RetriableReplSetConnectionTest < MongoTest::Base
  
  def connect(config)
    self.connection = ::Animoto::Mongo::RetriableReplSetConnection.new(*config['repl_set'])
  end

end

test = RetriableReplSetConnectionTest.new
test.setup_connection(YAML.load_file(config_path))
test.start_test
