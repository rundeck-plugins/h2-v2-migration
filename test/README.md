# Test for H2 database upgrade

This code performs a full automatic upgrade test of H2 database from v2 to v3 for Rundeck.

## Script

`test.sh` - provides full test as well as utility functions for different steps of the test

It can start a docker container for e.g. version 4.17.3 of Rundeck, load some data via the API, 
stop the container, upgrade the h2 database, and then start version 5.0.0 using that database,
then verify the DB contents are expected.

## Usage

`sh test/test.sh -r rundeck/rundeck -f 4.17.3 -t 5.0.0 -T`

Perform full upgrade test from `rundeck/rundeck:4.17.3` docker image to the `rundeck/rundeck:5.0.0` image.

## Examples

Test upgrade from 4.17.3 to SNAPSHOT for rundeck/rundeck

`test/test.sh -f 4.17.3 -t SNAPSHOT -r rundeck/rundeck -T`
    
Test upgrade from Rundeck versions between `4.1.0` and `4.17.x` to versions `5.0.0` and up, for rundeck/rundeck:

`test/test.sh -f 4.17.3 -t 5.0.0 -r rundeck/rundeck -T`

Test upgrade from Rundeck versions `4.0.1` and older, to versions between `4.1.0` and `4.17.x`:

`test/test.sh -f 4.0.1 -t 4.17.3 -r rundeck/rundeck -S v1 -D v2 -T`

Test upgrade from Rundeck versions `4.0.1` and older, to versions `5.0.0` and up:

`test/test.sh -f 4.0.1 -t 5.0.0 -r rundeck/rundeck -S v1 -D v3 -T`

If using rundeckpro/enterprise, you must specify license file with `-L` and agreement to license terms
with `-A true`

`test/test.sh -f 4.0.1 -t SNAPSHOT -r rundeckpro/enterprise -L path/to/license -A true -T`

## Utilities

The utility options to test.sh can be used to perform parts of the upgrade test in piecemeal fashion.

Perform just the h2 upgrade script for a workdir

`test/test.sh -d test/work/test-4.0.1 -u`

Restore the backup h2v1 files then upgrade again:

`test/test.sh -d test/work/test-4.0.1 -R -u`

Start Rundeck docker container using the workdir:

`test/test.sh -d test/work/test-4.0.1 -f 4.0.1 -r rundeckpro/enterprise -s`