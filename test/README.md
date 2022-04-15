# Test for H2 database upgrade

This code performs a full automatic upgrade test of H2 database from v1 to v2 for Rundeck.

## Script

`test.sh` - provides full test as well as utility functions for different steps of the test

It can start a docker container for e.g. version 3.4.10 of Rundeck, load some data via the API, 
stop the container, upgrade the h2 database, and then start version 4.1.0 using that database,
then verify the DB contents are expected.

## Usage

`sh test/test.sh -r rundeck/rundeck -f 3.4.10 -t 4.1.0 -T`

Perform full upgrade test from `rundeck/rundeck:3.4.10` docker image to the `rundeck/rundeck:4.1.0` image.

