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

## Example

Test upgrade from 3.4.10 to SNAPSHOT for rundeck/rundeck

`sh test/test.sh -f 3.4.10 -t SNAPSHOT -r rundeck/rundeck -T`

Test upgrade from 4.0.1 to SNAPSHOT for rundeck/rundeck

`sh test/test.sh -f 4.0.1 -t SNAPSHOT -r rundeck/rundeck -T`

If using rundeckpro/enterprise, you must specify license file with `-L` and agreement to license terms
with `-A true`

`sh test/test.sh -f 4.0.1 -t SNAPSHOT -r rundeckpro/enterprise -L path/to/license -A true -T`

## Utilities

The utility options to test.sh can be used to perform parts of the upgrade test in piecemeal fashion.

Perform just the h2 upgrade script for a workdir

`sh test/test.sh -d test/work/test-4.0.1 -u`

Restore the backup h2v1 files then upgrade again:

`sh test/test.sh -d test/work/test-4.0.1 -R -u`

Start Rundeck docker container using the workdir:

`sh test/test.sh -d test/work/test-4.0.1 -f 4.0.1 -r rundeckpro/enterprise -s`