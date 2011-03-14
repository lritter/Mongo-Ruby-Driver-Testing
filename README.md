This repo contains a bit of code to help with testing ruby mongo driver
retries.

Each sub directory contains test code for a different set of drivers and
approaches... It's all pretty hacky so, ymmv.


## Mongo Replication Set Setup

Taken from: http://www.mongodb.org/display/DOCS/Replica+Set+Tutorial 

On my Mac:

Create the data directories for the reply set:
        
        mkdir -p /usr/local/var/mongo_repl/r0
        mkdir -p /usr/local/var/mongo_repl/r1
        mkdir -p /usr/local/var/mongo_repl/r2

Then start up each instance:

        mongod --replSet repl_set --port 27017 --dbpath /usr/local/var/mongo_repl/r0
        mongod --replSet repl_set --port 27018 --dbpath /usr/local/var/mongo_repl/r1
        mongod --replSet repl_set --port 27019 --dbpath /usr/local/var/mongo_repl/r2

Initialize the set:

        bash$ mongo localhost:27017
        mongo > config = {_id: 'repl_set', members: [
                         {_id: 0, host: 'localhost:27017'},
                     {_id: 1, host: 'localhost:27018'},
                     {_id: 2, host: 'localhost:27019'}] 
                              } 
        mongo > rs.initiate(config);

Check the sets status with:

        mongo > rs.status()

Wait until every member has health 1.  All members should be in state 2 except
for one member that is in state 1

