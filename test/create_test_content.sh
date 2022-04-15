#!/bin/bash

#/ Use Rundeck API to add content to Rundeck server

set -euo pipefail
IFS=$'\n\t'
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SRC_DIR}/common.sh"

main() {
  local DATADIR=$1

  TOKEN=$(authenticate $DATADIR)
  [ -n "$TOKEN" ] && [ "null" != "$TOKEN" ] || die "Could not get auth TOKEN"

  #verify auth connection
  api_get "system/info" > "$DATADIR/system-info.json"
  [ 0 == $? ] || die "API test failed"
  assert_json_notnull "$DATADIR/system-info.json" ".system.rundeck.version" "System Info Version"

  # create 'test' project
  api_post "projects" '{"name":"test"}' >"$DATADIR/create-project.json"
  [ 0 == $? ] || die "Create project failed"
  VAL=$(jq -r .url "$DATADIR/create-project.json")
  VAL2=$(jq -r .errorCode "$DATADIR/create-project.json")
  { [ -n "$VAL" ] && [ "null" != "$VAL" ] ; } ||
    { [ -n "$VAL2" ] && [ "api.error.item.alreadyexists" == "$VAL2" ] ; } ||
    die "Could not create project: $VAL"

  # load test-job.xml
  VAL=$(api_jobxml_create "@${SRC_DIR}/test-job.xml" | jq -r ".succeeded[0].message + \"/\" + .skipped[0].error")
  [ 0 == $? ] || die "Create job failed"
  [ -n "$VAL" ] && [ "null" != "$VAL" ] || die "Could not get value: $VAL"
  echo "√ Created Job"

  # execution test job
  api_post "job/$JOBID/executions" '{}' >"$DATADIR/run1.json"
  [ 0 == $? ] || die "Execute job failed"

  execid=$(jq -r .id "$DATADIR/run1.json")
  [ -n "$execid" ] && [ "null" != "$execid" ] || die "Could not get execution id"
  echo "√ Created execution: $execid"

  #TODO: load webhook
}

main "${@}"