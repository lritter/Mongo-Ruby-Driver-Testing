#!/usr/bin/env ruby

$: << File.expand_path('../..', __FILE__)

require 'yaml'
require 'common/basic_test'

config_path = File.expand_path('../../db.config.yml', __FILE__)

module MongoTest
  class OneOneFour < Base

    def connect(config)
      self.connection = Mongo::Connection.multi(repl_set_nodes, options)
    end

  end

end

test = MongoTest::OneOneFour.new
test.setup_connection(YAML.load_file(config_path))
test.start_test
